### Helper functions for type, format and unit conversions

## Type conversions

# Overload Float functions in Base with new method to ignore missing values
Base.Float16(::Missing) = missing
Base.Float32(::Missing) = missing
Base.Float64(::Missing) = missing


"""
    convertFloats!(data::DataFrame, T::DataType=Float32)

Transform all columns of `Vector{AbstractFloat}` or `Vector{Union{Missing, AbstractFloat}}`
to the precision of type `T`.
"""
function convertFloats!(data::DataFrame, T::DataType=Float32)
  if isempty(data)
    for (i, col) in enumerate(eachcol(data))
      eltype(col) <: Union{Missing, AbstractFloat} && (data[!, i] = T[])
      eltype(col) <: Vector{<:Union{Missing, AbstractFloat}} &&
        (data[!, i] = Vector{T}[])
    end
  else
    for (i, col) in enumerate(eachcol(data))
      eltype(col) <: Union{Missing, AbstractFloat} && (data[!, i] = T.(col))
      eltype(col) <: Vector{<:Union{Missing, AbstractFloat}} &&
        (data[!, i] = [T.(c) for c in col])
    end
  end
end #function convertFloats!


## Time format conversion of satellite data

"""
    convertUTC(t::AbstractFloat) -> DateTime

Convert the CALIOP Profile UTC time (`t`) to a `DateTime`.
"""
function convertUTC(t::AbstractFloat)
  # Extract date from Float before decimal point and convert to Date
  date = floor(Int, t)
  d = Date(lpad(date, 8, "0"), "yyyymmdd")
  d += Dates.Year(2000)
  # Calculate overall time in seconds
  utc = (t - date) * 86400
  # From overall time, calculate hours, minutes, and seconds
  h = floor(Int, utc/3600)
  m = floor(Int, utc - 3600h)÷60
  s = floor(Int, utc - 3600h - 60m)
  ms = round(Int, 1000(utc - 3600h - 60m - s))

  # Return a DateTime from date and time (h/m/s) with timezone UTC
  return DateTime(Dates.yearmonthday(d)..., h, m, s, ms)
end #function convertUTC


## Data/unit conversion

"""
    earthradius(lat::T) -> R::T

Calculate the Earth's radius `R` in dependence of the current `lat`itude
considering the ellipsoidal shape of the Earth due to the rotational flattening.
"""
function earthradius(lat::T)::T where T<:AbstractFloat
  req, rpol = 6378137, 6356752
  √(((req^2*cosd(lat))^2 + (rpol^2*sind(lat))^2) / ((req*cosd(lat))^2 + (rpol*sind(lat))^2))
end #function earthradius


"""Convert feet to meters"""
function ft2m(ft::T)::T  where T<:Union{Missing,AbstractFloat}
    0.3048ft
end #function ft2m


"""Convert feet/min to m/s"""
function ftpmin2mps(ftpmin::T)::T  where T<:Union{Missing,AbstractFloat}
    0.00508ftpmin
end #function ftpmin2mps


"""Convert knots to m/s"""
function knot2mps(knot::T)::T  where T<:Union{Missing,AbstractFloat}
    1.852knot/3.6
end #function knot2mps
