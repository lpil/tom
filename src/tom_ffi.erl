-module(tom_ffi).
-export([
    infinity_to_dynamic/1,
    infinity_from_dynamic/1,
    nan_to_dynamic/1,
    nan_from_dynamic/1
]).

nan_to_dynamic({nan_value, positive}) -> 
    positive_nan;
nan_to_dynamic({nan_value, negative}) ->
    negative_nan.

nan_from_dynamic(positive_nan) ->
    {ok, {nan_value, positive}};
nan_from_dynamic(negative_nan) ->
    {ok, {nan_value, negative}};
nan_from_dynamic(_Other) ->
    % Value here is a placeholder
    {error, {nan_value, positive}}.

infinity_to_dynamic({infinity_value, positive}) -> 
    positive_infinity;
infinity_to_dynamic({infinity_value, negative}) ->
    negative_infinity.

infinity_from_dynamic(positive_infinity) ->
    {ok, {infinity_value, positive}};
infinity_from_dynamic(negative_infinity) ->
    {ok, {infinity_value, negative}};
infinity_from_dynamic(_Other) ->
    % Value here is a placeholder
    {error, {infinity_value, positive}}.

