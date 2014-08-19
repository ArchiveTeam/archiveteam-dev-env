#!/bin/bash -ex

WORKDIR=/tmp/

echo Post VM installing...

cd $WORKDIR

# Add service users
adduser tracker --disabled-login --gecos "" || :
echo -e "tracker\ntracker" | passwd tracker

adduser rsync --disabled-login --gecos "" || :
echo -e "rsync\nrsync" | passwd rsync

adduser --system www-data --group --disabled-password --disabled-login --no-create-home || :

sed --in-place -r "s/BLANK_TIME=[0-9]+/BLANK_TIME=0/" /etc/kbd/config

# Install dev libraries
cd /opt/
pip install -e "git+https://github.com/ArchiveTeam/seesaw-kit.git#egg=seesaw"
cd $WORKDIR

# Write info messages
cat <<'EOM' >/etc/issue
= ArchiveTeam Developer Environment (\n \l) =

Usernames available: dev, tracker, rsync
Tracker web interface: http://localhost:9080/global-admin/
Ports: SSH=9022, Rsync=9873

EOM

# Allow redis to take over the memory
sysctl vm.overcommit_memory=1
echo vm.overcommit_memory=1 >> /etc/sysctl.conf

# Install redis
wget http://download.redis.io/redis-stable.tar.gz --continue
tar xvzf redis-stable.tar.gz 
cd /tmp/redis-stable
make
make install
cd /tmp/redis-stable/utils
echo -e "\n\n\n\n/usr/local/bin/redis-server\n" | ./install_server.sh
cd $WORKDIR

# Make redis run not as root
invoke-rc.d redis_6379 stop
chown -R www-data:www-data /var/lib/redis/6379/
chown -R www-data:www-data /var/log/redis_6379.log
sed -i "s/\(pidfile *\).*/\1\/var\/run\/shm\/redis_6379.pid/" /etc/redis/6379.conf

cat <<'EOM' >/etc/init.d/redis_6379
#/bin/sh
EXEC="sudo -u www-data -g www-data /usr/local/bin/redis-server"
CLIEXEC="sudo -u www-data -g www-data /usr/local/bin/redis-cli"
PIDFILE=/var/run/shm/redis_6379.pid
CONF="/etc/redis/6379.conf"
REDISPORT="6379"

case "$1" in
    start)
        if [ -f $PIDFILE ]
        then
                echo "$PIDFILE exists, process is already running or crashed"
        else
                echo "Starting Redis server..."
                $EXEC $CONF
        fi
        ;;
    stop)
        if [ ! -f $PIDFILE ]
        then
                echo "$PIDFILE does not exist, process is not running"
        else
                PID=$(cat $PIDFILE)
                echo "Stopping ..."
                $CLIEXEC -p $REDISPORT shutdown
                while [ -x /proc/${PID} ]
                do
                    echo "Waiting for Redis to shutdown ..."
                    sleep 1
                done
                echo "Redis stopped"
        fi
        ;;
    *)
        echo "Please use start or stop as first argument"
        ;;
esac
EOM

# Stop redis logs from getting really big
cat <<'EOM' >/etc/logrotate.d/redis
/var/log/redis_*.log {
    daily
    rotate 10
    copytruncate
    delaycompress
    compress
    notifempty
    missingok
    size 10M
}
EOM


# Install nginx with passenger
curl -L get.rvm.io -o rvm_stable
sudo -i -u tracker bash -ex /tmp/rvm_stable --ignore-dotfiles --autolibs=0 --ruby
echo "source /home/tracker/.rvm/scripts/rvm" | sudo -u tracker tee --append /home/tracker/.bashrc /home/tracker/.profile
sudo -i -u tracker rvm requirements
sudo -i -u tracker rvm install 2.0
sudo -i -u tracker rvm rubygems current
sudo -i -u tracker gem install rails
sudo -i -u tracker gem install bundle
sudo -i -u tracker gem install passenger
sudo -i -u tracker passenger-install-nginx-module --auto --auto-download --prefix /home/tracker/nginx/

# Rotate the nginx logs
cat <<'EOM' >/etc/logrotate.d/nginx-tracker.conf
/home/tracker/nginx/logs/error.log
/home/tracker/nginx/logs/access.log {
    create rw tracker tracker
    daily
    rotate 10
    copytruncate
    delaycompress
    compress
    notifempty
    missingok
    size 10M
}
EOM

# Set up the nginx config
sudo -i -u tracker sed -i "s/\( root *\).*/\1\/home\/tracker\/universal-tracker\/public;passenger_enabled on;/" /home/tracker/nginx/conf/nginx.conf
sudo -i -u tracker sed -i "s/\( listen *\).*/\19080;/" /home/tracker/nginx/conf/nginx.conf

# Set up the upstart file for nginx
cat <<EOM >/etc/init/nginx-tracker.conf
description "nginx http daemon"

start on runlevel [2]
stop on runlevel [016]

setuid tracker
setgid tracker

console output

exec /home/tracker/nginx/sbin/nginx -c /home/tracker/nginx/conf/nginx.conf -g "daemon off;"
EOM

# Setup the tracker
if [ ! -d "/home/tracker/universal-tracker/" ]; then
	sudo -u tracker git clone https://github.com/ArchiveTeam/universal-tracker.git /home/tracker/universal-tracker/
fi
sudo -i -u tracker bundle install --gemfile /home/tracker/universal-tracker/Gemfile
cd $WORKDIR
cat <<'EOM' >/home/tracker/universal-tracker/config/redis.json
{
  "development": {
    "host": "127.0.0.1",
    "port": 6379,
    "db":   13
  },
  "test": {
    "host": "127.0.0.1",
    "port": 6379,
    "db":   14
  },
  "production": {
    "host":"127.0.0.1",
    "port":6379,
    "db": 1
  }
}
EOM
chown tracker:tracker /home/tracker/universal-tracker/config/redis.json

# Fix up tracker
cat <<'EOM' >>/home/tracker/universal-tracker/config.ru
if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    # We're in smart spawning mode.
    if forked
      # Re-establish redis connection
      redis.client.reconnect
    end
  end
end
EOM
chown tracker:tracker /home/tracker/universal-tracker/config.ru

# Set up tracker websocket
sudo cp -R /home/tracker/universal-tracker/broadcaster /home/tracker/.
cat <<'EOM' >/home/tracker/broadcaster/server.js
var fs = require('fs');
//var env = JSON.parse(fs.readFileSync('/home/dotcloud/environment.json'));

var env = {
    tracker_config: {
        redis_pubsub_channel: "tracker-log"
    },
    redis_db: 1
};

//var trackerConfig = JSON.parse(env['tracker_config']);
var trackerConfig = env['tracker_config'];

var app = require('http').createServer(httpHandler),
    io = require('socket.io').listen(app),
    redis = require('redis').createClient(Number(env['redis_port'] || 6379),
                                          env['redis_host'] || '127.0.0.1',
                                          Number(env['redis_db'] || 0)),
    numberOfClients = 0,
    recentMessages = {};

app.listen(9081);

redis.on("error", function (err) {
  console.log("Error " + err);
});

redis.on("message", redisHandler);

function httpHandler(request, response) {
  var m;
  if (m = request.url.match(/^\/recent\/(.+)/)) {
    var channel = m[1];
    response.writeHead(200, {"Content-Type": "text/plain; charset=UTF-8",
                             'Access-Control-Allow-Origin': '*',
                             'Access-Control-Allow-Credentials': 'true'});
    output = JSON.stringify(recentMessages[channel] || []);
    response.end(output);

  } else {
    response.writeHead(200, {"Content-Type": "text/plain"});
    output = "" + numberOfClients;
    response.end(output);
  }
}

function redisHandler(pubsubChannel, message) {
  console.log(message);
  var msgParsed = JSON.parse(message);
  console.log(msgParsed);
  var channel = msgParsed['log_channel'];
  if (!recentMessages[channel]) {
    recentMessages[channel] = [];
  }
  var msgList = recentMessages[channel];
  msgList.push(msgParsed);
  while (msgList.length > 20) {
    msgList.shift();
  }
  io.of('/'+channel).emit('log_message', message);
}


io.configure(function() {
  io.set("transports", ["websocket", "xhr-polling"]);
  io.set("polling duration", 10);

  var path = require('path');
  var HTTPPolling = require(path.join(
    path.dirname(require.resolve('socket.io')),'lib', 'transports','http-polling')
  );
  var XHRPolling = require(path.join(
    path.dirname(require.resolve('socket.io')),'lib','transports','xhr-polling')
  );

  XHRPolling.prototype.doWrite = function(data) {
    HTTPPolling.prototype.doWrite.call(this);

    var headers = {
      'Content-Type': 'text/plain; charset=UTF-8',
      'Content-Length': (data && Buffer.byteLength(data)) || 0
    };

    if (this.req.headers.origin) {
      headers['Access-Control-Allow-Origin'] = '*';
      if (this.req.headers.cookie) {
        headers['Access-Control-Allow-Credentials'] = 'true';
      }
    }

    this.response.writeHead(200, headers);
    this.response.write(data);
    // this.log.debug(this.name + ' writing', data);
  };
});

io.sockets.on('connection', function(socket) {
  numberOfClients++;
  socket.on('disconnect', function() {
    numberOfClients--;
  });
});


if (env['redis_password']) {
  redis.auth(env['redis_password']);
}
redis.subscribe(trackerConfig['redis_pubsub_channel']);
EOM
chown tracker:tracker /home/tracker/broadcaster/server.js

sudo -i -u tracker npm install socket.io --registry http://registry.npmjs.org/
sudo -i -u tracker npm install redis --registry http://registry.npmjs.org/

# upstart file for tracker websocket
cat <<'EOM' >/etc/init/nodejs-tracker.conf
description "tracker nodejs daemon"

start on runlevel [2]
stop on runlevel [016]

setuid tracker
setgid tracker

exec node /home/tracker/broadcaster/server.js
EOM

# Set up rsync
# Create a place to store rsync uploads
mkdir -p /home/rsync/uploads/
chown rsync:rsync /home/rsync/uploads
cat <<'EOM' >/etc/default/rsync
RSYNC_ENABLE=true
RSYNC_OPTS='--port 9873'
RSYNC_NICE=''
EOM

cat <<'EOM' >/etc/rsyncd.conf
[archiveteam]
path = /home/rsync/uploads/
use chroot = yes
max connections = 100
lock file = /var/lock/rsyncd
read only = no
list = yes
uid = rsync
gid = rsync
strict modes = yes
ignore errors = no
ignore nonreadable = yes
transfer logging = no
timeout = 600
refuse options = checksum dry-run
dont compress = *.gz *.tgz *.zip *.z *.rpm *.deb *.iso *.bz2 *.tbz
EOM

# Prefetch megawarc factory
if [ ! -d "/home/rsync/archiveteam-megawarc-factory/" ]; then
	sudo -u rsync git clone https://github.com/ArchiveTeam/archiveteam-megawarc-factory.git /home/rsync/archiveteam-megawarc-factory/
fi
if [ ! -d "/home/rsync/archiveteam-megawarc-factory/megawarc/" ]; then
	sudo -u rsync git clone https://github.com/alard/megawarc.git /home/rsync/archiveteam-megawarc-factory/megawarc/
fi

apt-get clean
rm /tmp/* --force --recursive || :

echo Done
