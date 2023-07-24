#!/usr/bin/env -S deno run -A
// https://github.com/runs-on/freebsd
// MIT License
// Copyright (c) 2023 runs-on
import * as core from "npm:@actions/core@1.10.0";
import { $ } from "npm:execa@7.1.1";
import * as YAML from "npm:yaml@2.3.1"

const runsOn = core.getInput("runs_on");
const steps = YAML.parse(core.getInput("steps"));
const env = core.getInput("env");
