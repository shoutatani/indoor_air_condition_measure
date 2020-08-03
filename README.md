# indoor_air_condition_measure

Ruby application For BME280 users and MH-Z19B users on Raspberry Pi.

Get current value from both BME280 and MH-Z19B, and save those values into S3, and post it to Slack channels.

---

## Installation

- just clone.

### Setup

- If you haven't install ruby yet, install ruby.

- and run bundle (install)

```shell
$ bundle install
```

- Next, create `.env` file in the directory. like this.

```shell
export SLACK_INDOOR_AIR_CANNEL='https://hooks.slack.com/services/xxxx/xxxx/xxxx'
export SLACK_INDOOR_CO2_CANNEL='https://hooks.slack.com/services/xxxx/xxxx/yyyy'
export S3_LOG_BUCKET='your-bucket-name'
```

- Last, setup your AWS Key on your machine, for logging data into the S3 bucket.

---

## Features

- When you start `entry-point.sh`, get values from sensors and log it on S3 bucket.

- If you'd like to start `entry-point.sh` at a regular interval, please setup crontab like crontab file in this repository.
