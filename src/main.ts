#!/usr/bin/env -S deno run -A
import * as core from "@actions/core";
import * as YAML from "yaml";
import { type, arrayOf } from "arktype";
import buildVM, {
  cacheBuiltVM,
  cacheHasBuiltVM,
  restoreBuiltVM,
} from "./buildVM.ts";

async function withGroup<A extends any[], R>(
  name: string,
  block: (...a: A) => Promise<R>,
  ...args: A
): Promise<R> {
  core.startGroup(name);
  try {
    return await block(...args);
  } finally {
    core.endGroup();
  }
}

const stepsT = arrayOf(
  type({
    "id?": "string",
    "if?": "boolean|string",
    "name?": "string",
    "uses?": "string",
    "run?": "string",
    "shell?": "string",
    "with?": "object",
    "env?": "object",
    "continue-on-error?": "boolean|string",
    "timeout-minutes?": "number|string",
  })
);

function throwIfInput(name: string): void {
  if (core.getInput(name)) {
    throw new DOMException(
      `Input ${name} is not supported. Did you mean to specify this at the ` +
        `job level? For more information on supported options, check out the ` +
        `GitHub readme: https://github.com/runs-on/freebsd-latest#readme`,
      "SyntaxError"
    );
  }
}

throwIfInput("name");
throwIfInput("permissions");
throwIfInput("needs");
throwIfInput("if");
throwIfInput("runs_on");
throwIfInput("environmment");
throwIfInput("concurrency");
throwIfInput("outputs");
throwIfInput("env");
throwIfInput("defaults");
// prettier-ignore
const steps = stepsT.assert(YAML.parse(core.getInput("steps", { required: true })));
throwIfInput("timeout_minutes");
throwIfInput("strategy");
throwIfInput("continue_on_error");
throwIfInput("container");
throwIfInput("services");
throwIfInput("uses");
throwIfInput("with");
throwIfInput("secrets");

await withGroup("🚚 Preparing FreeBSD runtime", async () => {
  if (await cacheHasBuiltVM()) {
    await withGroup("⚡ Using cached FreeBSD VM", restoreBuiltVM);
  } else {
    await withGroup("🔨 Building FreeBSD VM", buildVM);
  }
  await withGroup("⬆️ Updating cached FreeBSD VM", cacheBuiltVM);
});
await withGroup("🌟 main 🌟", async () => {});
