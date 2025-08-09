terraform {
  backend "gcs" {
    bucket = "tf_state_dev1"
    prefix = "state"
  }
}
