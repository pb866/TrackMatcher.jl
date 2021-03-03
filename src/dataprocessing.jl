### Helper functions for data processing
## Storage of intersection data
"""
    addX!(Xdata, track, accuracy, Xf, id, dx, dt, Xradius, Xflight,
      cpro, clay, tmf, tms, ift, feature, fxmeas, ftmeas, sxmeas, stmeas, NA)

Append DataFrames `Xdata`, `tracks`, and `accuracy` by data from `Xf`, `id`,
`dx`, `dt`, `Xflight`, `cpro`, `clay`, `tmf`, `tms`, `ift`, `feature`, `fxmeas`,
`ftmeas`, `sxmeas`, and `stmeas`. If an intersection already exists with `Xradius`
in `Xdata`, use the more accurate intersection with the lowest `accuracy.intersection`.
Altitude is retrieved from flight altitude or, for cloud tracks, set to `NA`
(`NaN` using the same floating point precision as other cloud data).
"""
function addX!(Xdata, track, accuracy, counter, Xf, id, dx, dt, Xradius, Xflight,
  cpro, clay, tmf, tms, ift, feature, fxmeas, ftmeas, sxmeas, stmeas, NA)

  # Set primary object's altitude
  alt = Xflight isa FlightTrack ? Xflight.data.alt[ift] : NA
  # Loop over previously found intersections
  for i = 1:size(Xdata, 1)
    # Use most accurate intersection, when duplicates are found within Xradius
    # or intersection with least decay between overpass times for equal accuracies
      accuracy.intersection[i], Xdata.tdiff[i], dt
    if dist.haversine(Xf, (Xdata.lat[i], Xdata.lon[i]), earthradius(Xf[1])) ≤ Xradius
      dx ≤ accuracy.intersection[i] || return counter # previous intersection more accurate
      # previous intersection equally accurate, but smaller delay time:
      (dx == accuracy.intersection[i] && abs(dt) > abs(Xdata.tdiff[i])) && return counter

      # Save more accurate duplicate
      Xdata[i, 2:end] = (lat = Xf[1], lon = Xf[2], alt = alt,
        tdiff = dt, tflight = tmf, tsat = tms, feature = feature)
      track[i, 2:end] = (flight = Xflight, CPro = cpro, CLay = clay)
      accuracy[i, 2:end] = (intersection = dx, flightcoord = fxmeas,
        satcoord = sxmeas, flighttime = ftmeas, sattime = stmeas)
      return counter
    end # duplicate condition based on accuracy
  end #loop over already found intersection
  # Save new intersections that are not identified as duplicates and increase counter
  counter += 1
  push!(Xdata, (id = id, lat = Xf[1], lon = Xf[2], alt = alt,
    tdiff = dt, tflight = tmf, tsat = tms, feature = feature))
  push!(track, (id = id, flight = Xflight, CPro = cpro, CLay = clay))
  push!(accuracy, (id = id, intersection = dx, flightcoord = fxmeas,
    satcoord = sxmeas, flighttime = ftmeas, sattime = stmeas))

  return counter
end #function addX!


## Data extractions from raw data

"""
    find_timespan(sat::DataFrame, X::Tuple{<:AbstractFloat, <:AbstractFloat}, dataspan::Int=15)
      -> DataFrame, Vector{Int}

From the `sat` data in a `DataFrame` and the intersection `X` (as lat/lon pair),
find the time indices `t` ± `dataspan` for which the distance at `t` is minimal to `X`.

Return a `DataFrame` with `sat` data in the time span together with a `Vector{Int}`
holding the file indices of the corresponding granule file(s).
The `sat` data may be smaller than the `dataspan` at the edges of the `sat` `DataFrame`.
"""
function find_timespan(sat::DataFrame, X::Tuple{<:AbstractFloat, <:AbstractFloat},
  dataspan::Int=15)
  # Find index in sat data array with minimum distance to analytic intersection solutin
  coords = ((sat.lat[i], sat.lon[i]) for i = 1:size(sat,1))
  imin = argmin(dist.haversine.(coords, [X], earthradius(X[1])))
  # Find first/last index of span acknowledging bounds of the data array
  t1 = max(1, min(imin-dataspan, length(sat.time)))
  t2 = min(length(sat.time), imin+dataspan)

  return sat.time[t1:t2], unique(sat.fileindex[t1:t2])
end #function find_timespan


"""
    extract_timespan(sat::T where T<:ObservationSet, timespan::Vector{DateTime})
      -> T where T<:ObservationSet

From the `sat` data of type `CLay` or `CPro`, extract a subset within `timespan`
and return the reduced struct.
"""
function extract_timespan(sat::Union{CLay,CPro}, timespan::Vector{DateTime})
  timeindex = [findfirst(sat.data.time .== t) for t in timespan
    if findfirst(sat.data.time .== t) ≠ nothing]
  satdata = sat.data[timeindex,:]
  typeof(sat) == CPro ? CPro(satdata) : CLay(satdata)
end #function extract_timespan


"""
    get_flightdata(flight::FlightTrack, X::Tuple{<:AbstractFloat, <:AbstractFloat}, primspan::Int)
      -> track::FlightTrack, index::Int

From the measured `flight` data and lat/lon coordinates the intersection `X`,
save the closest measured value to the interpolated intersection ±`primspan` data points
to `track` and return it together with the `index` in `track` of the time with the coordinates
closest to `X`.
"""
function get_flightdata(
  flight::FlightTrack{T},
  X::Tuple{<:AbstractFloat, <:AbstractFloat},
  primspan::Int
) where T
  # Generate coordinate pairs from lat/lon columns
  coords = ((flight.data.lat[i], flight.data.lon[i]) for i = 1:size(flight.data,1))
  # Find the index (DataFrame row) of the intersection in the flight data
  imin = argmin(dist.haversine.(coords, [X], earthradius(X[1])))
  # Construct FlightTrack at Intersection
  t1 = max(1, min(imin-primspan, length(flight.data.time)))
  t2 = min(length(flight.data.time), imin+primspan)
  # t2 = t-timespan > length(data[:,1]) ? 0 : t2
  track = FlightData{T}(flight.data[t1:t2,:], flight.metadata)

  flightcoords = ((track.data.lat[i], track.data.lon[i])
    for i = 1:size(track.data, 1))
  return track, argmin(dist.haversine.(flightcoords, [X], earthradius(X[1])))
end #function get_flightdata


"""
    get_DateTimeRoute(filename::String, tzone::String)

From the `filename` and a custom time zone string (`tzone`), extract and return
the starting date, the standardised time zone, the flight ID, origin, and destination.
"""
function get_DateTimeRoute(filename::String, tzone::String)

    # Time is the first column and has to be addressed as flight[!,1] in the code
    # due to different column names, in which the timezone is included
    timezone = zonedict[tzone]
    # Retrieve date and metadata from filename
    flightID, datestr, course = try match(r"(.*?)_(.*?)_(.*)", filename).captures
    catch
      println()
      println()
      @warn "Flight ID, date, and course not found. Data skipped." file
      return missing, missing, missing, missing, missing
    end
    orig, dest = match(r"(.*)[-|_](.*)", course).captures
    date = try Dates.Date(datestr, "d-u-y", locale="english")
    catch
      println()
      println()
      @warn "Unable to parse date. Data skipped." file
      return missing, missing, missing, missing, missing
    end

    return date, timezone, flightID, orig, dest
end


"""
    get_satdata(
      ms::mat.MSession,
      sat::SatData,
      X::Tuple{<:AbstractFloat, <:AbstractFloat},
      secspan::Int,
      flightalt::Real,
      flightid::Union{Int,String},
      lidarprofile::NamedTuple,
      lidarrange::Tuple{Real,Real},
      savesecondtype::Bool,
      Float::DataType=Float32
    ) -> cpro::CPro, clay::CLay, feature::Symbol, ts::Int

Using the `sat` data measurements within the overlap region and the MATLAB session
`ms`, extract CALIOP cloud profile (`cpro`) and/or layer data (`clay`) together with
the atmospheric `feature` at flight level (`flightalt`) for the data point closest
to the calculated intersection `X` ± `secspan` timesteps. In addition, return the
index `ts` within `cpro`/`clay` of the data point closest to `X`.
When `savesecondtype` is set to `false`, only the data type (`CLay`/`CPro`) in `sat`
is saved; if set to `true`, the corresponding data type is saved if available.
The lidar column data is saved for the height levels givin in the `lidarprofile` data
for the `lidarrange`. Floating point numbers are saved with single precision or
as defined by `Float`.
"""
function get_satdata(
  ms::mat.MSession,
  sat::SatData,
  X::Tuple{<:AbstractFloat, <:AbstractFloat},
  secspan::Int,
  flightalt::Real,
  altmin::Real,
  flightid::Union{Int,String},
  lidarprofile::NamedTuple,
  lidarrange::Tuple{Real,Real},
  savesecondtype::Bool,
  Float::DataType=Float32
)
  # Retrieve DataFrame at Intersection ± 15 time steps
  timespan, fileindex = find_timespan(sat.data, X, secspan)
  primfiles = map(f -> get(sat.metadata.files, f, 0), fileindex)
  secfiles = if sat.metadata.type == :CPro && savesecondtype
    replace.(primfiles, "CPro" => "CLay")
  elseif sat.metadata.type == :CLay && savesecondtype
    replace.(primfiles, "CLay" => "CPro")
  else
    String[]
  end

  # Get CPro/CLay data from near the intersection
  clay = if sat.metadata.type == :CLay
    CLay(ms, primfiles, lidarrange, altmin, Float)
  else
    try CLay(ms, secfiles, lidarrange, altmin, Float)
    catch
      println(); @warn "could not load additional layer data" flightid
      CLay()
    end
  end
  cpro = if sat.metadata.type == :CPro
    CPro(ms, primfiles, timespan, lidarprofile, Float)
  else
    try CPro(ms, secfiles, timespan, lidarprofile, Float)
    catch
      println(); @warn "could not load additional profile data" flightid
      CPro()
    end
  end
  clay = extract_timespan(clay, timespan)
  cpro = extract_timespan(cpro, timespan)

  # Define primary data and index of intersection in primary data
  primdata = sat.metadata.type == :CPro ? cpro : clay
  coords = ((primdata.data.lat[i], primdata.data.lon[i]) for i = 1:size(primdata.data, 1))
  ts = argmin(dist.haversine.(coords, [X], earthradius(X[1])))

  # Get feature classification
  feature = sat.metadata.type == :CPro ?
    atmosphericinfo(primdata, lidarprofile.fine, ts, flightalt, flightid) :
    atmosphericinfo(primdata, flightalt, ts)
  return cpro, clay, feature, ts
end #function get_satdata


"""
    interpolate_time(data::DataFrame, X::Tuple{T,T}  where T<:AbstractFloat) -> DateTime

Return the linearly interpolated time at `X` (a lat/lon coordinate pair)
to the `data` in a DataFrame with a `time`, `lat`, and `lon` column.

Time is linearly interpolated between the 2 closest points to `X`.
"""
function interpolate_time(data::DataFrame, X::Tuple{T,T}  where T<:AbstractFloat)
  # Calculate distances for each coordinate pair to X
  d = dist.haversine.(((φ, λ) for (φ, λ) in zip(data.lat, data.lon)), [X], earthradius(X[1]))
  index = closest_points(d)
  d = dist.haversine((data.lat[index[1]], data.lon[index[1]]),
    (data.lat[index[2]], data.lon[index[2]]), earthradius(data.lat[index[1]]))
  ds = dist.haversine((data.lat[index[1]], data.lon[index[1]]), X, earthradius(data.lat[index[1]]))
  dt = data.time[index[2]] - data.time[index[1]]
  round(data.time[index[1]] + Dates.Millisecond(round(ds/d*dt.value)), Dates.Second)
end #function interpolate_time
