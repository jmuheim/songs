// reveal-multiplex listens on every interface and takes no host setting. The
// specs' server has no business on the LAN, so it is kept on 127.0.0.1. The
// specs ask for any free port (PORT=0), so two runs at once never collide,
// and learn which one it got from PORT_FILE.
const fs = require('fs');
const http = require('http');

const listen = http.Server.prototype.listen;
http.Server.prototype.listen = function (port, ...rest) {
  if (process.env.PORT_FILE) {
    this.once('listening', () => fs.writeFileSync(process.env.PORT_FILE, String(this.address().port)));
  }
  return listen.call(this, port, '127.0.0.1', ...rest);
};
