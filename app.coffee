argv    = require('yargs').argv
geo2ecf = require 'geodetic-to-ecef'
path    = require 'path'
fs      = require 'fs'
proj    = require 'proj4'
geo     = require 'geodesy'
LA      = require 'look-alike'
#proj    = require 'proj4'

sidewalksLatLonFile = argv.in

console.log sidewalksLatLonFile


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

    @_computeECEFCoordinates()
    @

  _computeECEFCoordinates: () ->
    # Do not care about elevation (may be consider later).
    [@x, @y, @z] = geo2ecf @lat, @lon
    throw new Error("Not all axis exist: #{@x}, #{@y}, #{@z}") unless @x and @y and @z



connectCrossingSegments = (sidewalksPath) ->

  sidewalks = fs.readFileSync sidewalksPath
  sidewalks = JSON.parse sidewalks
  points = []

  # Get lat/lon for point-1 and lat/lon for point-2.
  # Exapmle:
  # Lines: [
  # {
  #   pointA: Point with the reference to pointB
  #   pointB: Point with the reference to pointA
  # },
  # ...
  # ]
  for sidewalk in sidewalks when sidewalk.Shape_Length > 0
    [[p1Lon, p1Lat], [p2Lon, p2Lat]] = sidewalk['Shape'][5]['paths'][0] # Line.
    p1 = new Point(p1Lat, p1Lon)
    p2 = new Point(p2Lat, p2Lon)
    [p1.other, p2.other] = [p2, p1]
    points.push p1
    points.push p2

  # Create KD-Tree of all points.
  la = new LA(points, {attributes: ['x', 'y', 'z']})

  vantagePoint = points[0]
  console.log {lat: vantagePoint.lat, lon: vantagePoint.lon}

  # Test. Find nearest neighbor for the first point in the array.
  top10 = la.query(points[0], {k: 10})

  nearestNeighbours = getListOfsidewalks top10

  console.log JSON.stringify(nearestNeighbours, null, 4)

  # If lines do intersect => store them as [lineA: [p1, p2], lineB: [p1, p2], intersect: [p1, p2]

getListOfsidewalks = (points) ->
  { point1: {lat: p.lat, lon: p.lon}, \
    point2: {lat: p.other.lat, lon: p.other.lon}} for p in points


  #getListOfsidewalks = (points) ->
  #  result = []
  #  for p in points
  #    p1 = proj('GOOGLE', 'WGS84', [p.lat, p.lon])
  #    p2 = proj('GOOGLE', 'WGS84', [p.other.lat, p.other.lon])
  #    console.log p1
  #    result.push(
  #      point1: {lat: p1.lat, lon: p1.lon}
  #      point2: {lat: p2.lat, lon: p2.lon} )
  #  result

connectCrossingSegments(sidewalksLatLonFile)


# Load file.
# Parse it from JSON.
# Clean it from 0 distances.
# Add atributes to each sidewalk: ecef => [x, y, z]
# *** We need to convert from geodetic coordinates in order
# *** to search for nearest neighbor in euclidean 3D space using kd-tree.
# Create a hashmap to store each sidewalk's endpointis.
# Sidewalk endpoint must refer to a sidewalk.
# {point_x_y_z => sidewalk} for connecting neighboring sidewalks
# to the common intersection point..
# [{x: 1, y:2, z:3}, ...] <-- for KD-Tree nearest neighbor search.
#
#      2
#      |     |
#    1-+-----+- <- sidewalk A
#      |     |
#      |     |
#     -+-----+-
#      |     |
#      ^
#      |
#  sidewalk B
#
# The nearest neighbor for the point 1 is going to be the point 2.
# This is the point that corresponds to one of the ends of the
# sidewalk B.
# Knowing that these two sidewalks are connected we can calculate the
# intersection of these two lines (arches actually) on the sphere using geodesy.
#
# After intersection for two neighboring points is found we can
# add the point and the corresponding sidewalks to the hashmap:
# {intersection_point_x_y_z => [sidewalk1, sidewalk2]}
# After the hashmap is built we can create a directed two way graph
# and connects its vertices accordingly to the hashmap. Each edge
# must have a weight hashmap with the length of the path and the
# directional altitude of the sidewalk.
#
# The rest is to connect the sidewalks by the crosswalks (use nearest
# neighbor search for the two nearest neighbors). The weight of the
# crosswalk edges must be zero.
#
###
#
{ sid: 45058,
    id: '45058',
    position: null,
    created_at: null,
    created_meta: null,
    updated_at: 0,
    updated_meta: null,
    meta: null,
    OBJECTID: '45058',
    Shape:
     [ null,
       '47.56492610400005',
       '-122.37618764899992',
       null,
       false,
       [Object] ],
    COMPKEY: '327118',
    COMPTYPE: '97',
    SEGKEY: '10371',
    DISTANCE: '23',
    ENDDISTANCE: '193',
    WIDTH: '37.5',
    UNITID: 'SDW-32792',
    UNITTYPE: 'SDW',
    UNITDESC: 'FAUNTLEROY WAY SW BETWEEN WEST SEATTLE BR EB AND SW GENESEE W ST, SE SIDE                                                                                                                                                                                      ',
    ADDBY: 'SW DATA LOAD',
    ADDDTTM: 1190852254,
    ASBLT: null,
    CONDITION: 'FAIR',
    CONDITION_ASSESSMENT_DATE: 1185951600,
    CURBTYPE: '410C',
    CURRENT_STATUS: 'INSVC',
    CURRENT_STATUS_DATE: 1280600840,
    FILLERTYPE: 'TR/AC',
    FILLERWID: '54',
    INSTALL_DATE: null,
    LEN: null,
    LENUOM: 'Feet',
    SW_WIDTH: '60',
    MAINTAINED_BY: ' ',
    MATL: ' ',
    MODBY: 'SDW_CONDITION_UPDATES',
    MODDTTM: 1280600804,
    OWNERSHIP: ' ',
    SIDE: 'SE',
    SURFTYPE: 'PCC',
    BUILDERCD: ' ',
    CURBRAMPHIGHYN: 'N',
    CURBRAMPMIDYN: 'N',
    CURBRAMPLOWYN: 'Y',
    INVALIDSWRECORDYN: 'N',
    MAINTBYRDWYSTRUCTYN: 'N',
    NOTSWCANDIDATEYN: 'N',
    SWINCOMPLETEYN: 'N',
    INCSTPOINTLOWEND: '0',
    INCSTPOINTUNKNOWN: 'N',
    MULTIPLESURFACEYN: 'N',
    GSITYPECD: ' ',
    HANSEN7ID: '067700410SE',
    ATTACHMENT_1: '\\\\sdotnasvfa\\sdot_vol1\\H8\\PROD\\ATTACHMENTS\\IMAGES\\SIDEWALKS\\A4070721002855.JPG',
    ATTACHMENT_2: null,
    ATTACHMENT_3: null,
    ATTACHMENT_4: null,
    ATTACHMENT_5: null,
    ATTACHMENT_6: null,
    ATTACHMENT_7: null,
    ATTACHMENT_8: null,
    ATTACHMENT_9: null,
    DATE_MVW_LAST_UPDATED: 1428203969,
    Shape_Length: '169.369278508794110393864684738218784332275390625' }
#
###
