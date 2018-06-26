#' Extract tremor features from raw accelerometer and gyroscope data.
#'
#' @param accelerometer_data A data frame with columns t, x, y, z containing 
#' accelerometer measurements. 
#' @param gyroscope_data A data frame with columns t, x, y, z containing 
#' gyroscope measurements.
#' @param gravity_data A data frame with columns t, x, y, z containing 
#' gravity sensor measurements.
#' @param funs Feature extraction functions that accept a single
#' time-series vector as input.
#' @param window_length Length of sliding windows.
#' @param time_range Timestamp range to use.
#' @param frequency_range Frequency range for the bandpass filter.
#' @param overlap Window overlap.
#' @return Tremor features indexed by axis and window.
#' @export
#' @author Thanneer Malai Perumal, Meghasyam Tummalacherla, Phil Snyder
#' @importFrom magrittr "%>%"
get_tremor_features <- function(
  accelerometer_data, gyroscope_data, gravity_data = NA,
  funs = c(time_domain_summary, frequency_domain_summary, frequency_domain_energy),
  window_length = 256, time_range = c(1,9), 
  frequency_range = c(1, 25), overlap = 0.5) {
  features = dplyr::tibble(Window = NA, error = NA)
  # check input integrity
  if (any(is.na(accelerometer_data))) {
    features$error = 'Malformed accelerometer data'
    return(features)
  } else if (any(is.na(gyroscope_data))) {
    features$error = 'Malformed gyroscope data'
    return(features)
  }
  
  # Get accelerometer features
  features_accel <- accelerometer_features(
    sensor_data = accelerometer_data, 
    funs = funs,
    window_length = window_length,
    overlap = overlap,
    time_range = time_range,
    frequency_range = frequency_range)
  
  # Get gyroscope features
  features_gyro <- gyroscope_features(
    sensor_data = gyroscope_data,
    funs = funs,
    window_length = window_length,
    overlap = overlap,
    time_range = time_range,
    frequency_range = frequency_range)
  
  # Return if processing is errored
  if(has_error(features_accel) || has_error(features_gyro)) {
    return(list(accelerometer = features_accel, gyroscope = features_gyro) %>%
             data.table::rbindlist(use.names = TRUE, fill = T, idcol = 'sensor'))
  }
  
  # tag outlier windows
  gr_error <- tag_outlier_windows(gravity_data, window_length, overlap)
  
  # Combine all features
  features <- list(accelerometer = features_accel, gyroscope = features_gyro) %>%
    data.table::rbindlist(use.names = TRUE, fill = T, idcol = 'sensor') %>%
    dplyr::mutate(window = as.character(window))
  if(is.na(gravity_data)) {
    features <- features %>%
      mutate(error = "None")
  } else {
    features <- features %>%
      dplyr::select(-error) %>% 
      dplyr::left_join(gr_error, by = 'window')
  }
  
  return(features)
}