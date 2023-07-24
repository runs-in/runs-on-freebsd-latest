#!/usr/bin/env -S deno run -A
import * as core from "npm:@actions/core@1.10.0";
import * as cache from "npm:@actions/cache@3.2.1";
import { $ } from "npm:execa@7.1.1";
import * as YAML from "npm:yaml@2.3.1";

const runsOn = core.getInput("runs_on");
const steps = YAML.parse(core.getInput("steps"));

core.startGroup("📥 Downloading VM")
