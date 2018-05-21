# Node-RED-OpenLV

This is the repository for the Node-Red Docker Container on the OpenLV Platform.
This README covers:

* [Container Construction](#container-construction)
* [MQTTS Certificates](#mqtts-certificates)
* [OpenLV Configuration](#openlv-configuration)
* [Node-Red API](#node-red-api)

# Container Construction

An example of how to build a Node-Red Docker container for development at v0.0.1

```bash
git clone https://github.com/techieyann/Node-Red-OpenLV.git
```
Build and add certs following [these](#mqtts-certificates) instructions.
```bash
docker build Node-Red-OpenLV/. -t imconsulting/node-red:0.0.1
docker save imconsulting/node-red:0.0.1 | xz -z -6 --x86 --lzma2 --threads=0 > imconsulting_node-red_00.tar
```
You should now have a tarball of a development Node-Red Docker container.

# MQTTS Certificates

The Makefile used to generate the keys is available [here](./keys/Makefile).
Make sure you copy your key and cert to the appropriate folder for production;
and when you build the Docker container, set the
[environment](./index.js#L6) properly.

# OpenLV configuration

This is the format of the configuration file with all supported keys and their
default values:

```
{
  "ContainerName": "imconsulting_node-red_00",
  "ContainerConfig": {
  {
    "flows": [],
    "adminRoot": "/editor",
    "adminAuth": [{
      "username": "admin",
      "password": "$2a$08$zZWtXTja0fB1pzD4sHCMyOCMYz2Z6dNbM6tl8sJogENOMcxWV9DN.",
      "permissions": "*"
    }],
    "auth: {
      "username": "user",
      "password": "$2a$08$zZWtXTja0fB1pzD4sHCMyOCMYz2Z6dNbM6tl8sJogENOMcxWV9DN."
    },
    "nodeRoot": "/",
    "dash": "dash"
  }
}
```

You can send any combination of fields, and any lacking will be supplied the
default value. You can technically send an empty config, and the container will
startup fine. Here are descriptions of the different ContainerConfig fields:

### ContainerConfig.adminRoot
This is the URL used to access the Admin UI, set to false to disable it. The
default is '/editor'.

### ContainerConfig.adminAuth
This is an array of user credentials allowed to log into the Admin UI, with
associated permissions ('read' for read-only, '*' for everything). The password
field must be a valid bcrypt hash, otherwise no one will be able to login
successfully. You may add as many users as you like.
The one default user is:
  username: 'admin'
  password: 'password'

### ContainerConfig.auth
This is the username and password required to access any of the output URLs
defined in the flows. The password field must be a valid bcrypt hash, otherwise
no one will be able to login successfully.
The container will use the default values if either or both are not supplied.
The defaults are:
  username: 'user'
  password: 'password' (hashed of course)

### ContainerConfig.nodeRoot
This is the root URL used by Node-Red to display flow outputs. It will be
prepended to any URL node defined in the flows. The default is merely the root
index.

### ContainerConfig.dash
This is the URL used by Node-Red's dashboard node. Don't let it overlap with
any flow definitions. Note there is no leading forward-slash.

### ContainerConfig.flows
This is a complete set of flows sent to Node-Red's setFlows function. This
container has all the default nodes installed, and also the following:
  node-red-contrib-facebook-messenger-writer
  node-red-contrib-googlechart
  node-red-dashboard
  node-red-node-dropbox
  node-red-node-google
Whatever Node-Red instance you create your flows on cannot use any other nodes
if you want to create a set of flows that will be accepted by this container.
If the Node-Red instance's HTTP API is accessible, you can get this array at:
    {Node-Red_IP}:1880/flows
If the HTTP API is disabled or secured, you can also get this through the
Editor UI:
  Select any node(s)
  access the hamburger menu in the top right
  select Export -> Clipboard
  select All Flows
This is the meat of the container, as without any flows Node-Red will sit idle.

### Credentials

For external API functionality, you must add the credentials manually as
Node-Red does not export this information. Generally, the instructions for how
to get the necessary information from the third party is available from the
Admin GUI when you're setting up nodes. And this information to the config;
here are the nodes you will have to edit (please note the type), and with what
lines:

#### Facebook-Messenger credentials
```
{
  "type": "facebook-messenger-writer",
  ...
  //add this line, with the token specific to your Messenger App.
  credentials: { token: "..."}
}
```

#### Google API credentials
```
{
  "type": "google-api-config",
  ...
  //add this line, with the key specific to your Google App
  "credentials": {"key": "..."}
}
```

#### Google credentials
```
{
  "type": "google-credentials",
  ...
  //add this object, with the info specific to your Google Account
  "credentials": {
    "displayName": "...",
    "clientId": "...",
    "clientSecret": "...",
    "accessToken": "...",
    "refreshToken": "...",
    "expireTime": "..."
  }
}
```

#### Dropbox credentials
```
{
    "type": "dropbox-config",
    ...
    //add this line, with the access token specific to your Dropbox App.
    "credentials":{"accesstoken":"..."},
}
```

#### Twitter credentials
```
{
    "type": "twitter-credentials",
    ...
    //this line will likely have been set for you already, just verify it
    "screen_name": "@twitterHandle",

    //add these lines, with the specifics from your Twitter App.
    "access_token": "...",
    "access_token_secret":"..."
    "consumer_key": "...",
    "consumer_secret":"..."
}
```

#### Email credentials
```
{
    "type": "e-mail",
    ...
    //verify this information
    "server": "smtp.gmail.com",
    "port": "465",
    "secure": true,
    //this is who the email is sent to
    "name": "goto@email.com",

    //add this line, with the appropriate user/pass combination.
    "credentials":{"userid":"...","password":"..."},
}
```

# Node-Red API

Subscribe, Unsubscribe, and Publish have all been exposed to Node-Red so you can
access them inside of function nodes and handle data accordingly.

Here is javascript showing use cases of all three:

```javascript
var lvcap = {
  sub: global.get('lvcapSub'),
  unsub: global.get('lvcapUnsub'),
  pub: global.get('lvcapPub')
};

lvcap.sub('mqtt/topic/here', function (message) {
    //callback on message received and sent to output node
    node.send({payload: message.Value});
});

lvcap.unsub('mqtt/topic/here', function() {
    //optional callback on successful unsubscribe
});

lvcap.pub('mqtt/topic/here', 'message to send', function () {
    //optional callback on successful publish
});
```

Only the most recent callback will be called on receipt of a message of a
particular topic.
