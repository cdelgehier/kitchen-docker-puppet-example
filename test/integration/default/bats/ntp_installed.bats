#!/usr/bin/env bats

@test "ntp rpm found" {
  run rpm -qa ntp
  [ "$status" -eq 0 ]
}
