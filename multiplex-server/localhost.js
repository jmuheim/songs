// reveal-multiplex listens on every interface and takes no host setting. The
// specs' server has no business on the LAN, so it is kept on 127.0.0.1.
const http = require('http');

const listen = http.Server.prototype.listen;
http.Server.prototype.listen = function (port, ...rest) {
  return listen.call(this, port, '127.0.0.1', ...rest);
};
