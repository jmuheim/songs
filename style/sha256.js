// SHA-256 of a string (UTF-8), as lowercase hex: window.sha256Hex(text).
//
// The relay forwards a message only when sha256(secret) == socketId, and every
// device derives the socketId from the session's secret in its URL
// (body-controls.html). Synchronous and self-contained on purpose:
// crypto.subtle is asynchronous and only exists in a secure context, so a
// phone reaching ./dev over the LAN by IP address would have no hash at all.
(function() {
  // The first 32 bits of the fractional parts of the square roots of the
  // first 8 primes (H0) and of the cube roots of the first 64 (K), as the
  // standard defines its constants.
  var H0 = [], K = [];
  function fraction(x) { return ((x - Math.floor(x)) * 0x100000000) | 0; }
  for (var n = 2; K.length < 64; n++) {
    var prime = true;
    for (var d = 2; d * d <= n; d++) if (n % d === 0) { prime = false; break; }
    if (!prime) continue;
    if (H0.length < 8) H0.push(fraction(Math.sqrt(n)));
    K.push(fraction(Math.cbrt(n)));
  }

  function rotr(x, n) { return (x >>> n) | (x << (32 - n)); }

  window.sha256Hex = function(text) {
    var bytes = new TextEncoder().encode(text);
    // The message, a 1 bit, zeros, and its length in bits as 64 bits: a
    // multiple of 64 bytes.
    var padded = new Uint8Array(Math.ceil((bytes.length + 9) / 64) * 64);
    padded.set(bytes);
    padded[bytes.length] = 0x80;
    var view = new DataView(padded.buffer);
    var bits = bytes.length * 8;
    view.setUint32(padded.length - 8, Math.floor(bits / 0x100000000));
    view.setUint32(padded.length - 4, bits >>> 0);

    var h = H0.slice(), w = new Int32Array(64);
    for (var offset = 0; offset < padded.length; offset += 64) {
      for (var i = 0; i < 16; i++) w[i] = view.getInt32(offset + i * 4);
      for (i = 16; i < 64; i++) {
        var s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        var s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) | 0;
      }
      var a = h[0], b = h[1], c = h[2], e = h[4], f = h[5], g = h[6], hh = h[7], dd = h[3];
      for (i = 0; i < 64; i++) {
        var t1 = (hh + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + ((e & f) ^ (~e & g)) + K[i] + w[i]) | 0;
        var t2 = ((rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) | 0;
        hh = g; g = f; f = e; e = (dd + t1) | 0;
        dd = c; c = b; b = a; a = (t1 + t2) | 0;
      }
      h[0] = (h[0] + a) | 0; h[1] = (h[1] + b) | 0; h[2] = (h[2] + c) | 0; h[3] = (h[3] + dd) | 0;
      h[4] = (h[4] + e) | 0; h[5] = (h[5] + f) | 0; h[6] = (h[6] + g) | 0; h[7] = (h[7] + hh) | 0;
    }
    return h.map(function(x) { return ('0000000' + (x >>> 0).toString(16)).slice(-8); }).join('');
  };
})();
