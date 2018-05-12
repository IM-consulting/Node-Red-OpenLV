var basicAuth = require('basic-auth');
var bcrypt = require('bcryptjs');

function basicAuthMiddleware(user,pass) {
    var checkPassword;
    var localCachedPassword;

    checkPassword = function(p) {
        return bcrypt.compareSync(p,pass);
    };

    var checkPasswordAndCache = function(p) {
        // For BasicAuth routes we know the password cannot change without
        // a restart of Node-RED. This means we can cache the provided crypted
        // version to save recalculating each time.
        if (localCachedPassword === p) {
            return true;
        }
        var result = checkPassword(p);
        if (result) {
            localCachedPassword = p;
        }
        return result;
    };

    return function(req,res,next) {
        if (req.method === 'OPTIONS') {
            return next();
        }
        var requestUser = basicAuth(req);
        if (!requestUser || requestUser.name !== user || !checkPasswordAndCache(requestUser.pass)) {
            res.set('WWW-Authenticate', 'Basic realm=Authorization Required');
            return res.sendStatus(401);
        }
        next();
    };
}

module.exports = basicAuthMiddleware;
