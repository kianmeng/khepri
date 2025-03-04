%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright (c) 2022 VMware, Inc. or its affiliates.  All rights reserved.
%%

-module(async_option).

-include_lib("eunit/include/eunit.hrl").

-include("include/khepri.hrl").
-include("src/internal.hrl").
-include("test/helpers.hrl").

async_unset_in_put_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             ?assertEqual(
                {ok, #{[foo] => #{}}},
                khepri_machine:put(?FUNCTION_NAME, [foo], none)),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_false_in_put_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             ?assertEqual(
                {ok, #{[foo] => #{}}},
                khepri_machine:put(
                  ?FUNCTION_NAME, [foo], none, #{async => false})),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_true_in_put_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             ?assertEqual(
                ok,
                khepri_machine:put(
                  ?FUNCTION_NAME, [foo], none, #{async => true})),
             lists:foldl(
               fun
                   (_, {ok, Result}) when Result =:= #{} ->
                       timer:sleep(500),
                       khepri_machine:get(?FUNCTION_NAME, [foo]);
                   (_, Ret) ->
                       Ret
               end, {ok, #{}}, lists:seq(1, 60)),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_with_correlation_in_put_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             Correlation = 1,
             ?assertEqual(
                ok,
                khepri_machine:put(
                  ?FUNCTION_NAME, [foo], none, #{async => Correlation})),
             Ret = receive
                       {ra_event, _, {applied, [{Correlation, Reply}]}} ->
                           Reply
                   end,
             ?assertEqual(
                {ok, #{[foo] => #{}}},
                Ret),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_with_priority_in_put_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             ?assertEqual(
                ok,
                khepri_machine:put(
                  ?FUNCTION_NAME, [foo], none, #{async => low})),
             lists:foldl(
               fun
                   (_, {ok, Result}) when Result =:= #{} ->
                       timer:sleep(500),
                       khepri_machine:get(?FUNCTION_NAME, [foo]);
                   (_, Ret) ->
                       Ret
               end, {ok, #{}}, lists:seq(1, 60)),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_with_correlation_and_priority_in_put_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             Correlation = 1,
             ?assertEqual(
                ok,
                khepri_machine:put(
                  ?FUNCTION_NAME, [foo], none,
                  #{async => {Correlation, low}})),
             Ret = receive
                       {ra_event, _, {applied, [{Correlation, Reply}]}} ->
                           Reply
                   end,
             ?assertEqual(
                {ok, #{[foo] => #{}}},
                Ret),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_unset_in_delete_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             ?assertEqual(
                {ok, #{[foo] => #{}}},
                khepri_machine:put(?FUNCTION_NAME, [foo], none)),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:delete(?FUNCTION_NAME, [foo])),
             ?assertEqual(
                {ok, #{}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_false_in_delete_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             ?assertEqual(
                {ok, #{[foo] => #{}}},
                khepri_machine:put(?FUNCTION_NAME, [foo], none)),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:delete(
                  ?FUNCTION_NAME, [foo], #{async => false})),
             ?assertEqual(
                {ok, #{}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_true_in_delete_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             ?assertEqual(
                {ok, #{[foo] => #{}}},
                khepri_machine:put(?FUNCTION_NAME, [foo], none)),
             ?assertEqual(
                ok,
                khepri_machine:delete(
                  ?FUNCTION_NAME, [foo], #{async => true})),
             lists:foldl(
               fun
                   (_, {ok, Result}) when Result =/= #{} ->
                       timer:sleep(500),
                       khepri_machine:get(?FUNCTION_NAME, [foo]);
                   (_, Ret) ->
                       Ret
               end,
               {ok, #{[foo] => #{payload_version => 1,
                                 child_list_version => 1,
                                 child_list_length => 0}}},
               lists:seq(1, 60)),
             ?assertEqual(
                {ok, #{}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_with_correlation_in_delete_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             ?assertEqual(
                {ok, #{[foo] => #{}}},
                khepri_machine:put(?FUNCTION_NAME, [foo], none)),
             Correlation = 1,
             ?assertEqual(
                ok,
                khepri_machine:delete(
                  ?FUNCTION_NAME, [foo], #{async => Correlation})),
             Ret = receive
                       {ra_event, _, {applied, [{Correlation, Reply}]}} ->
                           Reply
                   end,
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                Ret),
             ?assertEqual(
                {ok, #{}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_with_priority_in_delete_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             ?assertEqual(
                {ok, #{[foo] => #{}}},
                khepri_machine:put(?FUNCTION_NAME, [foo], none)),
             ?assertEqual(
                ok,
                khepri_machine:delete(
                  ?FUNCTION_NAME, [foo], #{async => low})),
             lists:foldl(
               fun
                   (_, {ok, Result}) when Result =/= #{} ->
                       timer:sleep(500),
                       khepri_machine:get(?FUNCTION_NAME, [foo]);
                   (_, Ret) ->
                       Ret
               end,
               {ok, #{[foo] => #{payload_version => 1,
                                 child_list_version => 1,
                                 child_list_length => 0}}},
               lists:seq(1, 60)),
             ?assertEqual(
                {ok, #{}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_with_correlation_and_priority_in_delete_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             ?assertEqual(
                {ok, #{[foo] => #{}}},
                khepri_machine:put(?FUNCTION_NAME, [foo], none)),
             Correlation = 1,
             ?assertEqual(
                ok,
                khepri_machine:delete(
                  ?FUNCTION_NAME, [foo], #{async => {Correlation, low}})),
             Ret = receive
                       {ra_event, _, {applied, [{Correlation, Reply}]}} ->
                           Reply
                   end,
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                Ret),
             ?assertEqual(
                {ok, #{}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_unset_in_transaction_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             Fun = fun() -> khepri_tx:put([foo], none) end,
             ?assertEqual(
                {atomic, {ok, #{[foo] => #{}}}},
                khepri_machine:transaction(?FUNCTION_NAME, Fun)),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_false_in_transaction_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             Fun = fun() -> khepri_tx:put([foo], none) end,
             ?assertEqual(
                {atomic, {ok, #{[foo] => #{}}}},
                khepri_machine:transaction(
                  ?FUNCTION_NAME, Fun, #{async => false})),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_true_in_transaction_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             Fun = fun() -> khepri_tx:put([foo], none) end,
             ?assertEqual(
                ok,
                khepri_machine:transaction(
                  ?FUNCTION_NAME, Fun, #{async => true})),
             lists:foldl(
               fun
                   (_, {ok, Result}) when Result =:= #{} ->
                       timer:sleep(500),
                       khepri_machine:get(?FUNCTION_NAME, [foo]);
                   (_, Ret) ->
                       Ret
               end, {ok, #{}}, lists:seq(1, 60)),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_with_correlation_in_transaction_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             Fun = fun() -> khepri_tx:put([foo], none) end,
             Correlation = 1,
             ?assertEqual(
                ok,
                khepri_machine:transaction(
                  ?FUNCTION_NAME, Fun, #{async => Correlation})),
             Ret = receive
                       {ra_event, _, {applied, [{Correlation, Reply}]}} ->
                           Reply
                   end,
             ?assertEqual(
                {ok, #{[foo] => #{}}},
                Ret),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_with_priority_in_transaction_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             Fun = fun() -> khepri_tx:put([foo], none) end,
             ?assertEqual(
                ok,
                khepri_machine:transaction(
                  ?FUNCTION_NAME, Fun, #{async => low})),
             lists:foldl(
               fun
                   (_, {ok, Result}) when Result =:= #{} ->
                       timer:sleep(500),
                       khepri_machine:get(?FUNCTION_NAME, [foo]);
                   (_, Ret) ->
                       Ret
               end, {ok, #{}}, lists:seq(1, 60)),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.

async_with_correlation_and_priority_in_transaction_test_() ->
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [?_test(
         begin
             Fun = fun() -> khepri_tx:put([foo], none) end,
             Correlation = 1,
             ?assertEqual(
                ok,
                khepri_machine:transaction(
                  ?FUNCTION_NAME, Fun,
                  #{async => {Correlation, low}})),
             Ret = receive
                       {ra_event, _, {applied, [{Correlation, Reply}]}} ->
                           Reply
                   end,
             ?assertEqual(
                {ok, #{[foo] => #{}}},
                Ret),
             ?assertEqual(
                {ok, #{[foo] => #{payload_version => 1,
                                  child_list_version => 1,
                                  child_list_length => 0}}},
                khepri_machine:get(?FUNCTION_NAME, [foo]))
         end)
     ]}.
