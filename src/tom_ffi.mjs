import { Result$Ok, Result$Error } from "./gleam.mjs";
import {
  Sign$Positive,
  Sign$Negative,
  Sign$isPositive,
  Sign$isNegative,
  InfinityValue$InfinityValue$sign,
  InfinityValue$InfinityValue,
  NanValue$NanValue$sign,
  NanValue$NanValue,
} from "./tom.mjs";

// We can't represent positive/negative NaNs in JS so we must have a representation for them
const negativeNaN = Symbol("-NaN");
const positiveNaN = Symbol("+NaN");

export function nan_to_dynamic(nan_value) {
  let sign = NanValue$NanValue$sign(nan_value);

  if (Sign$isPositive(sign)) {
    return positiveNaN;
  } else if (Sign$isNegative(sign)) {
    return negativeNaN;
  } else {
    // Should never happen by the type system
    throw "value is not a nan";
  }
}

export function nan_from_dynamic(value) {
  if (value == positiveNaN) {
    return Result$Ok(NanValue$NanValue(Sign$Positive()));
  } else if (value == negativeNaN) {
    return Result$Ok(NanValue$NanValue(Sign$Negative()));
  } else {
    // value here is a placeholder
    return Result$Error(NanValue$NanValue(Sign$Positive()));
  }
}

export function infinity_to_dynamic(infinity_value) {
  let sign = InfinityValue$InfinityValue$sign(infinity_value);

  if (Sign$isPositive(sign)) {
    return Infinity;
  } else if (Sign$isNegative(sign)) {
    return -Infinity;
  } else {
    // Should never happen by the type system
    throw "value is not an infinity";
  }
}

export function infinity_from_dynamic(value) {
  if (value == Infinity) {
    return Result$Ok(InfinityValue$InfinityValue(Sign$Positive()));
  } else if (value == -Infinity) {
    return Result$Ok(InfinityValue$InfinityValue(Sign$Negative()));
  } else {
    // value here is a placeholder
    return Result$Error(NanValue$NanValue(Sign$Positive()));
  }
}
