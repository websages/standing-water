#!/usr/bin/env node
var mqtt = require('mqtt');
var fs = require('fs');
console.log('wtf?');

/* cleartext settings [FUNCTIONAL]
var HOST = 'test.mosquitto.org';
var PORT = 1883;
*/

/* test.mosquitto.org ssl settings [FUNCTIONAL]
var TRUSTED_CA_LIST = fs.readFileSync('/etc/ssl/certs/mosquitto.org.crt');
var HOST = 'test.mosquitto.org';
var PORT = 8883;
*/

/* bikeshed settings */
var KEY = fs.readFileSync('/etc/ssl/private/localhost.ckey');
var CERT = fs.readFileSync('/etc/ssl/certs/localhost.crt');
var TRUSTED_CA_LIST = fs.readFileSync('/etc/ssl/certs/ca.crt');
var HOST = 'mqtt.hq.thebikeshed.io';
var PORT = 8883;
/**/

var options = {
  port: PORT,
  host: HOST,
  ca: TRUSTED_CA_LIST,
  rejectUnauthorized: false,
  secureProtocol: 'TLSv1_method',
  key: KEY,
  cert: CERT,
  ciphers: 'ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-RSA-RC4-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES128-SHA:AES256-SHA256:AES256-SHA:RC4-SHA:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS:!EDH',
  will: {
    topic: 'node/status',
    payload: new Buffer('offline')
  }

};

var client = mqtt.connect('mqtts://' + HOST, options);

client.on('connect', function () {
  console.log('Connected') 
  client.subscribe('#');
  client.publish('presence', 'Hello mqtt');
  client.publish('presence', 'Current time is: ' + new Date());
});

client.on('message', function (topic, message) {
  // message is Buffer
  console.log('[' + topic.toString() + '] ' + message.toString());
  client.end();
});
