#!/usr/bin/env zx

async function dfx_call(canister_name, fn_name, args) {
  const result = await $`dfx canister call ${canister_name} ${fn_name} ${args}`;
  return result.stdout;
}

await dfx_call("stress_test", "runRegion", "()");
