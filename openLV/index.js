require('http-shutdown').extend();
var http = require('http');
var express = require('express');
var RED = require('node-red');
var auth = require('./auth.js');

var app, server;

var started = false;

function initApp(settings, httpAuth, flows) {
  // Create an Express app
  app = express();

  // Create a server
  server = http.createServer(app).withShutdown();

  // Initialise the runtime with a server and settings
  RED.init(server, settings);

  // Serve the editor UI from settings.httpAdminRoot
  if (settings.httpAdminRoot)
    app.use(settings.httpAdminRoot, RED.httpAdmin);

  // Make sure they know the user and password
  app.use(settings.httpNodeRoot, auth(httpAuth.user, httpAuth.pass));
  // Serve the http nodes UI from settings.httpNodeRoot
  app.use(settings.httpNodeRoot,RED.httpNode);

  server.listen(1880);

  // Start the runtime
  RED.start().then(() => {
    started = true;
    RED.nodes.setFlows(flows, 'full');
  });
}

function startApp(settings, httpAuth, flows) {
  if (started === false) {
    initApp(settings, httpAuth, flows);
  }
  else {
    stopApp(function () {
      initApp(settings, httpAuth, flows);
    });
  }
}

function stopApp(callback) {
  if (started === false) {
    if (callback)
      callback();
  }
  else {
    RED.stop().then(() => {
      server.shutdown(() => {
        started = false;
        if (callback) callback();
      });
    });
  }

}

module.exports = {
  start: startApp,
  nodes: RED.nodes,
  stop: stopApp
};
