### Routines related to loading cloud track data

"""
    loadCloudTracks(files::String...; Float::DataType=Float32)

Load cloud track data from mat `files` and store in Julia format as `CloudTrack` structs.
Set the floating point precision to `Float` (default: `Float32`).
"""
function loadCloudTracks(
  files::String...;
  structname::String="filtered_trajectories",
  Float::DataType=Float32
)
  # Initialise
  tracks = CloudData[]
  # Loop over all mat files
  @pm.showprogress 1 "load cloud tracks..." for (i, file) in enumerate(files)
    # Read data from mat files
    t, latlon = readMAT(file, structname)
    # Store data in Julia format as Vector of CloudTrack structs
    storeMAT!(tracks, t, latlon, i, file; Float)
  end #loop over files

  return tracks
end #function loadCloudTracks


"""
    readMAT(file::String)

Read cloud track data from a mat `file`.
"""
function readMAT(file::String, structname::String="cloud")
  # Send file name to MATLAB
  data = MAT.matread(file)
  t = vec(data[structname]["timestamp"])
  latlon = vec(data[structname]["centrLatLon"])
  return t, latlon
end


"""
    storeMAT!(
      tracks::Vector{CloudData},
      t::Array,
      latlon::Array,
      fileID::Int,
      filename::String;
      Float::DataType=Float32
    )

Append the vector with cloud `tracks` by timestamps `t` and coordinates `latlon`
using the floating point precision set by `Float` (default: `Float32`) for the
positional data. Pass on `fileID` and `filename` to the metadata.
"""
function storeMAT!(
  tracks::Vector{CloudData},
  t::Array,
  latlon::Array,
  fileID::Int,
  filename::String;
  Float::DataType=Float32
)
  # Transform MATLAB data into Julia Format and store as CloudTrack struct in a vector
  for i = 1:length(t)
    data = DataFrame(time = vec(DateTime.(t[i], "yyyymmddHHMM")),
      lat = Float.(latlon[i][:,1]), lon = Float.(latlon[i][:,2]))
    # Determine predominant trajectory direction, inflection points, and remove duplicate entries
    flex, useLON = preptrack!(data)
    isempty(flex) && continue
    push!(tracks, CloudData{Float}(data, CloudMetadata{Float}(string(fileID, ".", i), data,
      flex, useLON, filename)))
  end
end #function storeMAT!
