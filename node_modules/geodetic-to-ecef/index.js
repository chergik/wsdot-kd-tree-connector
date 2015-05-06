// http://en.wikipedia.org/wiki/Geodetic_datum#From_geodetic_to_ECEF
// http://home.online.no/~sigurdhu/WGS84_Eng.html

var wgs84 = require('wgs84');
var a = wgs84.RADIUS; // equitorial radius (semi-major axis)
var f = wgs84.FLATTENING;
var e2 = (2 - f) * f; // first eccentricity squared

module.exports = function (lat, lon, elev) {
    var h = elev === undefined ? 0 : elev;
    var rlat = lat / 180 * Math.PI;
    var rlon = lon / 180 * Math.PI;
    
    var slat = Math.sin(rlat);
    var clat = Math.cos(rlat);
    
    var N = a / Math.sqrt(1 - e2 * slat*slat);
    
    var x = (N + h) * clat * Math.cos(rlon);
    var y = (N + h) * clat * Math.sin(rlon);
    var z = (N * (1 - e2) + h) * slat;
    return [ x, y, z ];
};
