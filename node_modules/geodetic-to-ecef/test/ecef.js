var test = require('tape');
var wgs84 = require('wgs84');
var ecef = require('../');

test('oakland', function (t) {
    t.deepEqual(
        ecef(37.8043722, -122.2708026),
        [ -2694044.4111565403, -4266368.805493665, 3888310.602276871 ],
        'sea level'
    );
    t.deepEqual(
        ecef(37.8043722, -122.2708026, 300000),
        [ -2820601.154138873, -4466787.825369031, 4072200.806686735 ],
        '300km up in space'
    );
    
    t.ok(
        approx(
            dist(ecef(37.8043722, -122.2708026, 300000)),
            wgs84.RADIUS + 300000
        ), 'space distance'
    );
    t.ok(
        approx(
            dist(ecef(37.8043722, -122.2708026)),
            wgs84.RADIUS
        ), 'ground distance'
    );
    
    t.ok(
        approx(
            dist(ecef(37.8043722, -122.2708026, -4000)),
            wgs84.RADIUS - 4000
        ), 'underground distance'
    );
    
    t.end();
});

function approx (a, b) {
    return (a - b) / ((a + b) / 2) < 0.01;
}

function dist (xyz) {
    var x = xyz[0], y = xyz[1], z = xyz[2];
    return Math.sqrt(x*x + y*y + z*z);
}
