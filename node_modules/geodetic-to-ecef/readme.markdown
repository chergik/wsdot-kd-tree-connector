# geodetic-to-ecef

convert [geodetic coordinates](https://en.wikipedia.org/wiki/World_Geodetic_System)
([lat,lon])
to [ecef](http://en.wikipedia.org/wiki/ECEF) (cartesian [x,y,z])

[![build status](https://secure.travis-ci.org/substack/geodetic-to-ecef.png)](http://travis-ci.org/substack/geodetic-to-ecef)

# example

``` js
var ecef = require('geodetic-to-ecef');
var xyz = ecef(37.8043722, -122.2708026);
console.log(xyz);
```

output:

```
$ node ecef.js
[ -2694044.4111565403, -4266368.805493665, 3888310.602276871 ]
```

# methods

``` js
var ecef = require('geodetic-to-ecef')
```

## var xyz = ecef(lat, lon, elevation=0)

Return an array `xyz` of `[x,y,z]` coordinates in meters from `lat` and `lon`.

Optionally supply an `elevation` in meters.

# install

With [npm](https://npmjs.org) do:

```
npm install geodetic-to-ecef
```

# license

MIT
