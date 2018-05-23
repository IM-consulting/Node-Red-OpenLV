var lvcap = require('lv-cap');
var OAuth = require('oauth');
var app = require('./openLV/index.js');

//dev @ 0.0.6 prod @ 1.0.0
var env = 'prod';//'prod';

var options = {
  containerId: 'imconsulting_node-red_00',
  keyPath: './' + env + '/imconsulting_node-red.key',
  certPath: './' + env + '/imconsulting_node-red.crt',
  rejectUnauthorized: false,//true,
  debug: true
};

var started = false;

var configurationCB = function (config) {
  if (started) {
    lvcap.setStatus('RESTART');
  }
  else {
    var flows = config.flows || [];

    var settings = {
      httpAdminRoot: config.adminRoot ? config.adminRoot.toString() : false,
      adminAuth: {
        type: 'credentials',
        users: [{
          username: 'admin',
          password: '$2a$08$zZWtXTja0fB1pzD4sHCMyOCMYz2Z6dNbM6tl8sJogENOMcxWV9DN.',
          permissions: '*'
        }]
      },
      httpNodeRoot: config.nodeRoot ? config.nodeRoot.toString() : "/",
      ui: { path: config.dash ? config.dash.toString() : "dash" },
      functionGlobalContext: {
        lvcapPub: lvcap.publish,
        lvcapSub: lvcap.subscribe,
        lvcapUnsub: lvcap.unsubscribe,
      }
    };

    if (config.adminAuth && Array.isArray(config.adminAuth)) {
      settings.adminAuth.users = config.adminAuth;
    }

    var httpAuth =  {
      user: 'user',
      pass: '$2a$08$zZWtXTja0fB1pzD4sHCMyOCMYz2Z6dNbM6tl8sJogENOMcxWV9DN.'
    };
    if (config.auth) {
      if (config.auth.username) httpAuth.user = config.auth.username.toString();
      if (config.auth.password) httpAuth.pass = config.auth.password.toString();
    }

    app.start(settings, httpAuth, flows);
    started = true;
  }

};

var shutdownCB = function () {
  app.nodes.setFlows([]);
  app.stop();
};

lvcap.start(options, configurationCB, shutdownCB);
