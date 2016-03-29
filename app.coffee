argv          = require('yargs').argv
gju           = require 'geojson-utils'
geo2ecf       = require 'geodetic-to-ecef'
path          = require 'path'
fs            = require 'fs'
createKdTree  = require 'static-kdtree'
LatLon        = require('geodesy').LatLonEllipsoidal
LatLonVectors = require('geodesy').LatLonVectors

sidewalksLatLonFile = argv.in

class Point

  ###
  # Point with decimal lat and lon coordinates as well
  # as with ECEF (x, y, z) coordinates.
  # @param lat
  #           decimal latitude
  # @param lon
  #           decimal longitude
  # @param other
  #           other point of the line
  #           it can be set later and is null by default
  ###
  constructor: (@lat, @lon, @other=null) ->
    if !typeof(@lat) is "number" or !typeof(@lon) is "number"
      throw new Error("Lat and lon must be present")

    @latLon = new LatLon @lat, @lon
    @latLonVectors = new LatLonVectors @lat, @lon

    @_computeECEFCoordinates()
    @

  _computeECEFCoordinates: ->
    # Do not care about elevation (may be consider later).
    [@x, @y, @z] = geo2ecf @lat, @lon

  isAnyXyzCoordinatesZero: ->
    not (@x and @y and @z)

  updateTo: (point) ->
    @lat = point.lat
    @lon = point.lon
    @latLon = new LatLon @lat, @lon
    @latLonVectors = new LatLonVectors @lat, @lon
    @_computeECEFCoordinates()

class PointsMap

  constructor: (@points=[]) ->
    @map = []
    @buildMap()

  getKey: (point) ->
    "#{point.x}|#{point.y}|#{point.z}"

  getKeyByXyz: (x, y ,z) ->
    "#{x}|#{y}|#{z}"

  buildMap: ->
    @map[@getKey point] = point for point in @points

  addPoint: (point) ->
    @points.push point
    @map[@getKey point] = point

  getPoint: ->
    [x, y, z] = arguments
    @map[@getKeyByXyz(x, y, z)]

  getXyzPoints: ->
    @xyz = ([p.x, p.y, p.z] for p in @points)


# The sidewalks data is dirty in a sence of crosswalks being represented by the
# adjacent sections, which almost never end/start at the same point and cannot be
# used to build a directed graph (which later could have being used to build shortest
# paths using preferably Dijkstra or Bellman-Ford).
#
# Current algorithm connect the beginning and the end of intersecting adjacent segments of the
# sidewalks at each intersection. It does so by converting lat/lon to the Earch Centered Coordinated
# in 3D to later put those into the KD-Tree (i.e. 3D-Tree). Then it go through points of the sidewalks
# and for each search the neighboring points (i.e. candidates for the intersection/connection).
# KD-Tree is very efficient for such search operations (i.e. log(n) on average and linear otherwise).
# Once neighboring points found, we examine corresponding segments for intersection and connect them if
# positive.
#
# The better solution would be to use Machine Learning (e.g. train a classifier
# using train/validation/test split and run predictions on data).
connectCrossingSegments = (sidewalksPath) ->

  sidewalks = fs.readFileSync sidewalksPath
  sidewalks = JSON.parse sidewalks

  # Get lat/lon for point-1 and lat/lon for point-2.
  # Exapmle:
  # Lines: [
  # {
  #   pointA: Point with the reference to pointB
  #   pointB: Point with the reference to pointA
  # },
  # ...
  # ]
  points = []
  # For all sidewalks (but avoid those with zero length).
  for sidewalk in sidewalks when sidewalk.Shape_Length > 0
    [[p1Lon, p1Lat], [p2Lon, p2Lat]] = sidewalk['Shape'][5]['paths'][0] # Line.
    p1 = new Point(p1Lat, p1Lon)
    p2 = new Point(p2Lat, p2Lon)

    # Avoid trash data.
    continue if p1.isAnyXyzCoordinatesZero() or p2.isAnyXyzCoordinatesZero()

    [p1.other, p2.other] = [p2, p1]
    points.push p1
    points.push p2

  pointsMap = new PointsMap(points)
  xyzPoints = pointsMap.getXyzPoints()
  kdTree    = createKdTree xyzPoints

  all_neighbours = []
  modified_neighbours = []

  # Later will do it for each point.
  for vantagePoint, vantagePointIndex in pointsMap.points
    process.stderr.write "Processing point ##{vantagePointIndex + 1}\n"
    vantageXyzPoint   = xyzPoints[vantagePointIndex]
    nearestXyzPoints  = kdTree.knn vantageXyzPoint, 10
    neighbours        = getPointObjects pointsMap, nearestXyzPoints

    # For given list of points each with the reference to the OTHER point,
    # and the vantage point with the OTHER reference too, iterate through
    # list of points except the vantage point and vantage point.OTHER and
    # compute the intersection of current point's line segment and the
    # vantage point line segment. If intersection found - stop.
    # Better to use arches intersection equation.
    #console.log "VP: #{vantagePoint.latLon.lat}, #{vantagePoint.latLon.lon}," +
    #            " #{vantagePoint.other.latLon.lat}, #{vantagePoint.other.latLon.lon}"

    for point in neighbours when vantagePoint != point &&
                                 vantagePoint.other != point

      intersection = findIntersection(vantagePoint, point)

      if intersection

        # Update two line segments to end at the same intersecting point.
        # Find the point from the line1 and then closest point from the line2
        # to the point of the intersection.
        # Set both to the point of intersection.
        point1ToUpdate = pointClosestToIntersection(vantagePoint, intersection)
        point2ToUpdate = pointClosestToIntersection(point, intersection)

        #console.log "Point1ToUpdate: #{JSON.stringify point1ToUpdate.latLonVectors, null, 4}, Point2ToUpdate: #{JSON.stringify point2ToUpdate.latLonVectors, null, 4}"

        point1ToUpdate.updateTo intersection
        point2ToUpdate.updateTo intersection

        #console.log "Point1ToUpdate: #{JSON.stringify point1ToUpdate.latLonVectors, null, 4}, Point2ToUpdate: #{JSON.stringify point2ToUpdate.latLonVectors, null, 4}"

        break

  console.log JSON.stringify getListOfsidewalks(pointsMap.points), null, 4

pointClosestToIntersection = (point, intersection) ->
  if point.latLonVectors.distanceTo(intersection.latLonVectors) <
     point.other.latLonVectors.distanceTo(intersection.latLonVectors)
  then point else point.other

getListOfsidewalksByIndexes = (pointsMap, pointsIndexes) ->
  sidewalks = for p in pointsIndexes
    p = pointsMap.points[p]
    { point1: {lat: p.lat, lon: p.lon}, \
      point2: {lat: p.other.lat, lon: p.other.lon}}

getListOfsidewalks = (points) ->
  sidewalks = for p in points
    #process.stderr.write "p.latLon: #{p.latLon}\n"
    #process.stderr.write "p.latLon.other: #{p.other.latLon}\n"
    { point1: {lat: p.lat, lon: p.lon}, \
      point2: {lat: p.other.lat, lon: p.other.lon}}

getPointObjects = (pointsMap, points) ->
  (pointsMap.points[pIndex] for pIndex in points)

findIntersection = (p1, p2) ->
  intersection = gju.lineStringsIntersect(
    { "type": "LineString", "coordinates": [[p1.lon, p1.lat],
                                            [p1.other.lon, p1.other.lat]] },
    { "type": "LineString", "coordinates": [[p2.lon, p2.lat], [p2.other.lon, p2.other.lat]] })

  if intersection
    intersection = intersection[0]["coordinates"]
    #process.stderr.write JSON.stringify intersection, null, 4
    new Point intersection[0], intersection[1]
  else
    null

connectCrossingSegments(sidewalksLatLonFile)

