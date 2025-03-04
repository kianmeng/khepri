%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright (c) 2022 VMware, Inc. or its affiliates.  All rights reserved.
%%

-module(triggers).

-include_lib("eunit/include/eunit.hrl").

-include("include/khepri.hrl").
-include("src/internal.hrl").
-include("test/helpers.hrl").

event_triggers_associated_sproc_test_() ->
    EventFilter = #kevf_tree{path = [foo]},
    StoredProcPath = [sproc],
    Key = ?FUNCTION_NAME,
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [{inorder,
       [{"Storing a procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, StoredProcPath,
              #kpayload_sproc{
                 sproc = make_sproc(self(), Key)}))},

        {"Registering a trigger",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              ?FUNCTION_NAME,
              EventFilter,
              StoredProcPath))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, [foo], #kpayload_data{data = value}))},

        {"Checking the procedure was executed",
         ?_assertEqual(executed, receive_sproc_msg(Key))}]
      }]}.

event_using_matching_pattern_triggers_associated_sproc_test_() ->
    EventFilter = #kevf_tree{path = [foo, #if_child_list_length{count = 0}]},
    StoredProcPath = [sproc],
    Key = ?FUNCTION_NAME,
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [{inorder,
       [{"Storing a procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, StoredProcPath,
              #kpayload_sproc{
                 sproc = make_sproc(self(), Key)}))},

        {"Registering a trigger",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              ?FUNCTION_NAME,
              EventFilter,
              StoredProcPath))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, [foo, bar], #kpayload_data{data = value}))},

        {"Checking the procedure was executed",
         ?_assertEqual(executed, receive_sproc_msg(Key))}]
      }]}.

event_using_non_matching_pattern1_does_not_trigger_associated_sproc_test_() ->
    EventFilter = #kevf_tree{
                     path = [?STAR, #if_child_list_length{count = 1}]},
    StoredProcPath = [sproc],
    Key = ?FUNCTION_NAME,
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [{inorder,
       [{"Storing a procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, StoredProcPath,
              #kpayload_sproc{
                 sproc = make_sproc(self(), Key)}))},

        {"Registering a trigger",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              ?FUNCTION_NAME,
              EventFilter,
              StoredProcPath))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, [foo, bar], #kpayload_data{data = value}))},

        {"Checking the procedure was executed",
         ?_assertEqual(timeout, receive_sproc_msg(Key))}]
      }]}.

event_using_non_matching_pattern2_does_not_trigger_associated_sproc_test_() ->
    EventFilter = #kevf_tree{path = [foo]},
    StoredProcPath = [sproc],
    Key = ?FUNCTION_NAME,
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [{inorder,
       [{"Storing a procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, StoredProcPath,
              #kpayload_sproc{
                 sproc = make_sproc(self(), Key)}))},

        {"Registering a trigger",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              ?FUNCTION_NAME,
              EventFilter,
              StoredProcPath))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, [foo, bar], #kpayload_data{data = value}))},

        {"Checking the procedure was executed",
         ?_assertEqual(timeout, receive_sproc_msg(Key))}]
      }]}.

event_using_non_matching_pattern3_does_not_trigger_associated_sproc_test_() ->
    EventFilter = #kevf_tree{path = [foo, bar]},
    StoredProcPath = [sproc],
    Key = ?FUNCTION_NAME,
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [{inorder,
       [{"Storing a procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, StoredProcPath,
              #kpayload_sproc{
                 sproc = make_sproc(self(), Key)}))},

        {"Registering a trigger",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              ?FUNCTION_NAME,
              EventFilter,
              StoredProcPath))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, [foo], #kpayload_data{data = value}))},

        {"Checking the procedure was executed",
         ?_assertEqual(timeout, receive_sproc_msg(Key))}]
      }]}.

event_does_not_trigger_unassociated_sproc_test_() ->
    EventFilter = #kevf_tree{path = [foo]},
    StoredProcPath = [sproc],
    Key = ?FUNCTION_NAME,
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [{inorder,
       [{"Storing a procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, StoredProcPath,
              #kpayload_sproc{
                 sproc = make_sproc(self(), Key)}))},

        {"Registering a trigger",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              ?FUNCTION_NAME,
              EventFilter,
              StoredProcPath))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, [bar], #kpayload_data{data = value}))},

        {"Checking the procedure was executed",
         ?_assertEqual(timeout, receive_sproc_msg(Key))}]
      }]}.

event_does_not_trigger_non_existing_sproc_test_() ->
    EventFilter = #kevf_tree{path = [foo]},
    StoredProcPath = [sproc],
    Key = ?FUNCTION_NAME,
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [{inorder,
       [{"Storing a procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, [non_existing | StoredProcPath],
              #kpayload_sproc{
                 sproc = make_sproc(self(), Key)}))},

        {"Registering a trigger",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              ?FUNCTION_NAME,
              EventFilter,
              StoredProcPath))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, [bar], #kpayload_data{data = value}))},

        {"Checking the procedure was executed",
         ?_assertEqual(timeout, receive_sproc_msg(Key))}]
      }]}.

event_does_not_trigger_data_node_test_() ->
    EventFilter = #kevf_tree{path = [foo]},
    StoredProcPath = [sproc],
    Key = ?FUNCTION_NAME,
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [{inorder,
       [{"Storing a procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, StoredProcPath,
              #kpayload_data{
                 data = not_an_stored_proc}))},

        {"Registering a trigger",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              ?FUNCTION_NAME,
              EventFilter,
              StoredProcPath))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, [bar], #kpayload_data{data = value}))},

        {"Checking the procedure was executed",
         ?_assertEqual(timeout, receive_sproc_msg(Key))}]
      }]}.

filter_on_change_type_test_() ->
    CreatedEventFilter = #kevf_tree{path = [foo],
                                    props = #{on_actions => [create]}},
    UpdatedEventFilter = #kevf_tree{path = [foo],
                                    props = #{on_actions => [update]}},
    DeletedEventFilter = #kevf_tree{path = [foo],
                                    props = #{on_actions => [delete]}},
    StoredProcPath = [sproc],
    CreatedKey = {?FUNCTION_NAME, created},
    UpdatedKey = {?FUNCTION_NAME, updated},
    DeletedKey = {?FUNCTION_NAME, deleted},
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [{inorder,
       [{"Storing a procedure for `created` change",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, StoredProcPath ++ [created],
              #kpayload_sproc{
                 sproc = make_sproc(self(), CreatedKey)}))},

        {"Storing a procedure for `updated` change",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, StoredProcPath ++ [updated],
              #kpayload_sproc{
                 sproc = make_sproc(self(), UpdatedKey)}))},

        {"Storing a procedure for `deleted` change",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, StoredProcPath ++ [deleted],
              #kpayload_sproc{
                 sproc = make_sproc(self(), DeletedKey)}))},

        {"Registering a `created` trigger",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              created,
              CreatedEventFilter,
              StoredProcPath ++ [created]))},

        {"Registering a `updated` trigger",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              updated,
              UpdatedEventFilter,
              StoredProcPath ++ [updated]))},

        {"Registering a `deleted` trigger",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              deleted,
              DeletedEventFilter,
              StoredProcPath ++ [deleted]))},

        {"Creating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, [foo], #kpayload_data{data = value1}))},

        {"Checking the `created` procedure was executed",
         ?_assertEqual(executed, receive_sproc_msg(CreatedKey))},
        {"Checking the `updated` procedure was not executed",
         ?_assertEqual(timeout, receive_sproc_msg(UpdatedKey))},
        {"Checking the `deleted` procedure was not executed",
         ?_assertEqual(timeout, receive_sproc_msg(DeletedKey))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, [foo], #kpayload_data{data = value2}))},

        {"Checking the `created` procedure was not executed",
         ?_assertEqual(timeout, receive_sproc_msg(CreatedKey))},
        {"Checking the `updated` procedure was executed",
         ?_assertEqual(executed, receive_sproc_msg(UpdatedKey))},
        {"Checking the `deleted` procedure was not executed",
         ?_assertEqual(timeout, receive_sproc_msg(DeletedKey))},

        {"Deleting a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:delete(
              ?FUNCTION_NAME, [foo]))},

        {"Checking the `created` procedure was not executed",
         ?_assertEqual(timeout, receive_sproc_msg(CreatedKey))},
        {"Checking the `updated` procedure was not executed",
         ?_assertEqual(timeout, receive_sproc_msg(UpdatedKey))},
        {"Checking the `deleted` procedure was executed",
         ?_assertEqual(executed, receive_sproc_msg(DeletedKey))}]
      }]}.

a_buggy_sproc_does_not_crash_state_machine_test_() ->
    EventFilter = #kevf_tree{path = [foo]},
    StoredProcPath = [sproc],
    Key = ?FUNCTION_NAME,
    {setup,
     fun() -> test_ra_server_helpers:setup(?FUNCTION_NAME) end,
     fun(Priv) -> test_ra_server_helpers:cleanup(Priv) end,
     [{inorder,
       [{"Storing a working procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, StoredProcPath ++ [good],
              #kpayload_sproc{
                 sproc = make_sproc(self(), Key)}))},

        {"Storing a failing procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, StoredProcPath ++ [bad],
              #kpayload_sproc{
                 sproc = fun(_Props) -> throw("Expected crash") end}))},

        {"Registering trigger 1",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              good,
              EventFilter,
              StoredProcPath ++ [good]))},

        {"Registering trigger 2",
         ?_assertEqual(
            ok,
            khepri_machine:register_trigger(
              ?FUNCTION_NAME,
              bad,
              EventFilter#kevf_tree{props = #{priority => 10}},
              StoredProcPath ++ [bad]))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            khepri_machine:put(
              ?FUNCTION_NAME, [foo], #kpayload_data{data = 1}))},

        {"Checking the procedure was executed",
         ?_assertEqual(executed, receive_sproc_msg(Key))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            begin
                timer:sleep(2000),
                khepri_machine:put(
                  ?FUNCTION_NAME, [foo], #kpayload_data{data = 2})
            end)},

        {"Checking the procedure was executed",
         ?_assertEqual(executed, receive_sproc_msg(Key))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            begin
                timer:sleep(2000),
                khepri_machine:put(
                  ?FUNCTION_NAME, [foo], #kpayload_data{data = 3})
            end)},

        {"Checking the procedure was executed",
         ?_assertEqual(executed, receive_sproc_msg(Key))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            begin
                timer:sleep(2000),
                khepri_machine:put(
                  ?FUNCTION_NAME, [foo], #kpayload_data{data = 4})
            end)},

        {"Checking the procedure was executed",
         ?_assertEqual(executed, receive_sproc_msg(Key))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            begin
                timer:sleep(2000),
                khepri_machine:put(
                  ?FUNCTION_NAME, [foo], #kpayload_data{data = 5})
            end)},

        {"Checking the procedure was executed",
         ?_assertEqual(executed, receive_sproc_msg(Key))},

        {"Updating a node; should trigger the procedure",
         ?_assertMatch(
            {ok, _},
            begin
                timer:sleep(2000),
                khepri_machine:put(
                  ?FUNCTION_NAME, [foo], #kpayload_data{data = 6})
            end)},

        {"Checking the procedure was executed",
         ?_assertEqual(executed, receive_sproc_msg(Key))}]
      }]}.

make_sproc(Pid, Key) ->
    fun(_Props) ->
            Pid ! {sproc, Key, executed}
    end.

receive_sproc_msg(Key) ->
    receive {sproc, Key, executed} -> executed
    after 1000                     -> timeout
    end.
