%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright (c) 2021-2022 VMware, Inc. or its affiliates.  All rights reserved.
%%

%% @doc Khepri high-level and cluster management API.
%%
%% This module exposes the high-level API to manipulate data and the cluster
%% management API.
%%
%% == Cluster management ==
%%
%% === Starting a Ra system ===
%%
%% The default store is based on Ra's default system. You need to change the
%% Ra application configuration if you want to set settings. That said, it is
%% recommended to start your own Ra system. This way, even though Ra is
%% already running, you can choose where the Khepri data should be stored.
%% This is also required if you need to run multiple database instances in
%% parallel.
%%
%% Here is a quick start example:
%%
%% ```
%% %% We start Khepri. Ra is also started because Khepri depends on it.
%% {ok, _} = application:ensure_all_started(khepri),
%%
%% %% We define the configuration of the Ra system for our database. Here, we
%% %% only care about the directory where data will be written.
%% RaSystem = my_ra_system,
%% RaSystemDataDir = "/path/to/storage/dir",
%% DefaultSystemConfig = ra_system:default_config(),
%% RaSystemConfig = DefaultSystemConfig#{name => RaSystem,
%%                                       data_dir => RaSystemDataDir,
%%                                       wal_data_dir => RaSystemDataDir,
%%                                       names => ra_system:derive_names(
%%                                                  RaSystem)},
%%
%% %% The configuration is ready, let's start the Ra system.
%% {ok, _RaSystemPid} = ra_system:start(RaSystemConfig),
%%
%% %% At last we can start Khepri! We need to choose a name for the Ra cluster
%% %% running in the Ra system started above. This must be an atom.
%% RaClusterName = my_khepri_db,
%% RaClusterFriendlyName = "My Khepri DB",
%% {ok, StoreId} = khepri:start(
%%                   RaSystem,
%%                   RaClusterName,
%%                   RaClusterFriendlyName),
%%
%% %% The Ra cluster name is our "store ID" used everywhere in the Khepri API.
%% khepri:insert(StoreId, [stock, wood], 156).
%% '''
%%
%% Please refer to <a href="https://github.com/rabbitmq/ra">Ra
%% documentation</a> to learn more about Ra systems and Ra clusters.
%%
%% === Managing Ra cluster members ===
%%
%% To add a member to your Ra cluster:
%%
%% ```
%% khepri:add_member(
%%   RaSystem,
%%   RaClusterName,
%%   RaClusterFriendlyName,
%%   NewMemberErlangNodename).
%% '''
%%
%% To remove a member from your Ra cluster:
%%
%% ```
%% khepri:remove_member(
%%   RaClusterName,
%%   MemberErlangNodenameToRemove).
%% '''
%%
%% == Data manipulation ==
%%
%% See individual functions for more details.

-module(khepri).

-include_lib("kernel/include/logger.hrl").

-include("include/khepri.hrl").
-include("src/khepri_fun.hrl").
-include("src/internal.hrl").

-export([start/0,
         start/1,
         start/3,
         add_member/2,
         add_member/4,
         remove_member/1,
         remove_member/2,
         reset/2,
         members/1,
         locally_known_members/1,
         nodes/1,
         locally_known_nodes/1,
         get_store_ids/0,

         put/2, put/3, put/4, put/5,
         create/2, create/3, create/4, create/5,
         update/2, update/3, update/4, update/5,
         compare_and_swap/3, compare_and_swap/4, compare_and_swap/5,
         compare_and_swap/6,
         wrap_payload/1,

         clear_payload/1, clear_payload/2, clear_payload/3, clear_payload/4,
         delete/1, delete/2, delete/3,

         exists/1, exists/2, exists/3,
         get/1, get/2, get/3,
         get_node_props/1, get_node_props/2, get_node_props/3,
         has_data/1, has_data/2, has_data/3,
         get_data/1, get_data/2, get_data/3,
         has_sproc/1, has_sproc/2, has_sproc/3,
         run_sproc/2, run_sproc/3, run_sproc/4,
         register_trigger/3, register_trigger/4, register_trigger/5,

         list/1, list/2, list/3,
         find/2, find/3, find/4,

         transaction/1, transaction/2, transaction/3, transaction/4,

         clear_store/0, clear_store/1, clear_store/2,

         no_payload/0,
         data_payload/1,
         sproc_payload/1,

         info/0,
         info/1]).

-compile({no_auto_import, [get/2, put/2, erase/1]}).

%% FIXME: Dialyzer complains about several functions with "optional" arguments
%% (but not all). I believe the specs are correct, but can't figure out how to
%% please Dialyzer. So for now, let's disable this specific check for the
%% problematic functions.
-if(?OTP_RELEASE >= 24).
-dialyzer({no_underspecs, [put/2, put/3,
                           create/2, create/3,
                           update/2, update/3,
                           compare_and_swap/3, compare_and_swap/4,
                           exists/2,
                           has_data/2,
                           get_data/2,
                           has_sproc/2,
                           run_sproc/3,
                           transaction/2, transaction/3]}).
-endif.

-type store_id() :: ra:cluster_name().
%% ID of a Khepri store.

-type ok(Type) :: {ok, Type}.

-type error() :: error(any()).

-type error(Type) :: {error, Type}.
%% Return value of a failed command or query.

-export_type([store_id/0,
              ok/1,
              error/0]).

%% -------------------------------------------------------------------
%% Database management.
%% -------------------------------------------------------------------

-spec start() -> {ok, store_id()} | {error, any()}.

start() ->
    khepri_clustering:start().

-spec start(atom()) ->
    {ok, store_id()} | {error, any()}.

start(RaSystem) ->
    khepri_clustering:start(RaSystem).

-spec start(atom(), ra:cluster_name(), string()) ->
    {ok, store_id()} | {error, any()}.

start(RaSystem, ClusterName, FriendlyName) ->
    khepri_clustering:start(RaSystem, ClusterName, FriendlyName).

add_member(RaSystem, NewNode) ->
    khepri_clustering:add_member(RaSystem, NewNode).

add_member(RaSystem, ClusterName, FriendlyName, NewNode) ->
    khepri_clustering:add_member(RaSystem, ClusterName, FriendlyName, NewNode).

remove_member(NodeToRemove) ->
    khepri_clustering:remove_member(NodeToRemove).

remove_member(ClusterName, NodeToRemove) ->
    khepri_clustering:remove_member(ClusterName, NodeToRemove).

reset(RaSystem, ClusterName) ->
    khepri_clustering:reset(RaSystem, ClusterName).

members(ClusterName) ->
    khepri_clustering:members(ClusterName).

locally_known_members(ClusterName) ->
    khepri_clustering:locally_known_members(ClusterName).

nodes(ClusterName) ->
    khepri_clustering:nodes(ClusterName).

locally_known_nodes(ClusterName) ->
    khepri_clustering:locally_known_nodes(ClusterName).

-spec get_store_ids() -> [store_id()].

get_store_ids() ->
    khepri_clustering:get_store_ids().

%% -------------------------------------------------------------------
%% Data manipulation.
%% This is the simple API. The complete/advanced one is exposed by the
%% `khepri_machine' module.
%% -------------------------------------------------------------------

-spec put(PathPattern, Data) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Result :: khepri_machine:result().
%% @doc Creates or modifies a specific tree node in the tree structure.
%%
%% Calling this function is the same as calling `put(StoreId, PathPattern,
%% Data)' with the default store ID.
%%
%% @see put/3.

put(PathPattern, Data) ->
    put(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Data).

-spec put(StoreId, PathPattern, Data) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Result :: khepri_machine:result().
%% @doc Creates or modifies a specific tree node in the tree structure.
%%
%% Calling this function is the same as calling `put(StoreId, PathPattern,
%% Data, #{}, #{})'.
%%
%% @see put/5.

put(StoreId, PathPattern, Data) ->
    put(StoreId, PathPattern, Data, #{}, #{}).

-spec put(StoreId, PathPattern, Data, Extra | Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Extra :: #{keep_while => khepri_machine:keep_while_conds_map()},
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result() | NoRetIfAsync,
      NoRetIfAsync :: ok.
%% @doc Creates or modifies a specific tree node in the tree structure.
%%
%% Calling this function is the same as calling `put(StoreId, PathPattern,
%% Data, Extra, Options)' with an empty `Extra' or `Options'.
%%
%% @see put/5.

put(StoreId, PathPattern, Data, #{keep_while := _} = Extra) ->
    put(StoreId, PathPattern, Data, Extra, #{});
put(StoreId, PathPattern, Data, Options) ->
    put(StoreId, PathPattern, Data, #{}, Options).

-spec put(StoreId, PathPattern, Data, Extra, Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Extra :: #{keep_while => khepri_machine:keep_while_conds_map()},
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result() | NoRetIfAsync,
      NoRetIfAsync :: ok.
%% @doc Creates or modifies a specific tree node in the tree structure.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% The provided data is embedded in a {@link khepri_machine:payload_data()} or
%% {@link khepri_machine:payload_sproc()} record before it can be stored in
%% the database.
%%
%% Once the path is normalized to a list of tree node names and conditions, it
%% calls {@link khepri_machine:put/5}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the node to create or
%%        modify.
%% @param Data the Erlang term or function to store.
%% @param Extra extra options such as `keep_while' conditions.
%% @param Options command options such as the command type.
%%
%% @returns in the case of a synchronous put, an "ok" tuple with a map with one
%% entry, or an "error" tuple; in the case of an asynchronous put, always `ok'
%% (the actual return value may be sent by a message if a correlation ID was
%% specified).
%%
%% @see khepri_machine:put/5.

put(StoreId, PathPattern, Data, Extra, Options) ->
    do_put(StoreId, PathPattern, Data, Extra, Options).

-spec create(PathPattern, Data) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Result :: khepri_machine:result().
%% @doc Creates a specific tree node in the tree structure only if it does not
%% exist.
%%
%% Calling this function is the same as calling `create(StoreId, PathPattern,
%% Data)' with the default store ID.
%%
%% @see create/3.

create(PathPattern, Data) ->
    create(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Data).

-spec create(StoreId, PathPattern, Data) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Result :: khepri_machine:result().
%% @doc Creates a specific tree node in the tree structure only if it does not
%% exist.
%%
%% Calling this function is the same as calling `create(StoreId, PathPattern,
%% Data, #{}, #{})'.
%%
%% @see create/5.

create(StoreId, PathPattern, Data) ->
    create(StoreId, PathPattern, Data, #{}, #{}).

-spec create(StoreId, PathPattern, Data, Extra | Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Extra :: #{keep_while => khepri_machine:keep_while_conds_map()},
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result() | NoRetIfAsync,
      NoRetIfAsync :: ok.
%% @doc Creates a specific tree node in the tree structure only if it does not
%% exist.
%%
%% Calling this function is the same as calling `create(StoreId, PathPattern,
%% Data, Extra, Options)' with an empty `Extra' or `Options'.
%%
%% @see create/5.

create(StoreId, PathPattern, Data, #{keep_while := _} = Extra) ->
    create(StoreId, PathPattern, Data, Extra, #{});
create(StoreId, PathPattern, Data, Options) ->
    create(StoreId, PathPattern, Data, #{}, Options).

-spec create(StoreId, PathPattern, Data, Extra, Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Extra :: #{keep_while => khepri_machine:keep_while_conds_map()},
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result() | NoRetIfAsync,
      NoRetIfAsync :: ok.
%% @doc Creates a specific tree node in the tree structure only if it does not
%% exist.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% The `PathPattern' is then modified to include an `#if_node_exists{exists =
%% false}' condition on its last component.
%%
%% The provided data is embedded in a {@link khepri_machine:payload_data()} or
%% {@link khepri_machine:payload_sproc()} record before it can be stored in
%% the database.
%%
%% Once the path is normalized to a list of tree node names and conditions,
%% and updated, it calls {@link khepri_machine:put/5}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the node to create.
%% @param Data the Erlang term or function to store.
%% @param Extra extra options such as `keep_while' conditions.
%% @param Options command options such as the command type.
%%
%% @returns in the case of a synchronous put, an "ok" tuple with a map with one
%% entry, or an "error" tuple; in the case of an asynchronous put, always `ok'
%% (the actual return value may be sent by a message if a correlation ID was
%% specified).
%%
%% @see khepri_machine:put/5.

create(StoreId, PathPattern, Data, Extra, Options) ->
    PathPattern1 = khepri_path:from_string(PathPattern),
    PathPattern2 = khepri_path:combine_with_conditions(
                     PathPattern1, [#if_node_exists{exists = false}]),
    do_put(StoreId, PathPattern2, Data, Extra, Options).

-spec update(PathPattern, Data) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Result :: khepri_machine:result().
%% @doc Updates a specific tree node in the tree structure only if it already
%% exists.
%%
%% Calling this function is the same as calling `update(StoreId, PathPattern,
%% Data)' with the default store ID.
%%
%% @see update/3.

update(PathPattern, Data) ->
    update(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Data).

-spec update(StoreId, PathPattern, Data) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Result :: khepri_machine:result().
%% @doc Updates a specific tree node in the tree structure only if it already
%% exists.
%%
%% Calling this function is the same as calling `update(StoreId, PathPattern,
%% Data, #{}, #{})'.
%%
%% @see update/5.

update(StoreId, PathPattern, Data) ->
    update(StoreId, PathPattern, Data, #{}, #{}).

-spec update(StoreId, PathPattern, Data, Extra | Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Extra :: #{keep_while => khepri_machine:keep_while_conds_map()},
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result() | NoRetIfAsync,
      NoRetIfAsync :: ok.
%% @doc Updates a specific tree node in the tree structure only if it already
%% exists.
%%
%% Calling this function is the same as calling `update(StoreId, PathPattern,
%% Data, Extra, Options)' with an empty `Extra' or `Options'.
%%
%% @see update/5.

update(StoreId, PathPattern, Data, #{keep_while := _} = Extra) ->
    update(StoreId, PathPattern, Data, Extra, #{});
update(StoreId, PathPattern, Data, Options) ->
    update(StoreId, PathPattern, Data, #{}, Options).

-spec update(StoreId, PathPattern, Data, Extra, Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Extra :: #{keep_while => khepri_machine:keep_while_conds_map()},
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result() | NoRetIfAsync,
      NoRetIfAsync :: ok.
%% @doc Updates a specific tree node in the tree structure only if it already
%% exists.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% The `PathPattern' is then modified to include an `#if_node_exists{exists =
%% true}' condition on its last component.
%%
%% The provided data is embedded in a {@link khepri_machine:payload_data()} or
%% {@link khepri_machine:payload_sproc()} record before it can be stored in
%% the database.
%%
%% Once the path is normalized to a list of tree node names and conditions,
%% and updated, it calls {@link khepri_machine:put/5}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the node to modify.
%% @param Data the Erlang term or function to store.
%% @param Extra extra options such as `keep_while' conditions.
%% @param Options command options such as the command type.
%%
%% @returns in the case of a synchronous put, an "ok" tuple with a map with one
%% entry, or an "error" tuple; in the case of an asynchronous put, always `ok'
%% (the actual return value may be sent by a message if a correlation ID was
%% specified).
%%
%% @see khepri_machine:put/5.

update(StoreId, PathPattern, Data, Extra, Options) ->
    PathPattern1 = khepri_path:from_string(PathPattern),
    PathPattern2 = khepri_path:combine_with_conditions(
                     PathPattern1, [#if_node_exists{exists = true}]),
    do_put(StoreId, PathPattern2, Data, Extra, Options).

-spec compare_and_swap(PathPattern, DataPattern, Data) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      DataPattern :: ets:match_pattern(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Result :: khepri_machine:result().
%% @doc Updates a specific tree node in the tree structure only if it already
%% exists and its data matches the given `DataPattern'.
%%
%% Calling this function is the same as calling `compare_and_swap(StoreId,
%% PathPattern, DataPattern, Data)' with the default store ID.
%%
%% @see compare_and_swap/4.

compare_and_swap(PathPattern, DataPattern, Data) ->
    compare_and_swap(?DEFAULT_RA_CLUSTER_NAME, PathPattern, DataPattern, Data).

-spec compare_and_swap(StoreId, PathPattern, DataPattern, Data) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      DataPattern :: ets:match_pattern(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Result :: khepri_machine:result().
%% @doc Updates a specific tree node in the tree structure only if it already
%% exists and its data matches the given `DataPattern'.
%%
%% Calling this function is the same as calling `compare_and_swap(StoreId,
%% PathPattern, DataPattern, Data, #{}, #{})'.
%%
%% @see compare_and_swap/6.

compare_and_swap(StoreId, PathPattern, DataPattern, Data) ->
    compare_and_swap(StoreId, PathPattern, DataPattern, Data, #{}, #{}).

-spec compare_and_swap(
        StoreId, PathPattern, DataPattern, Data, Extra | Options) ->
    Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      DataPattern :: ets:match_pattern(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Extra :: #{keep_while => khepri_machine:keep_while_conds_map()},
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result() | NoRetIfAsync,
      NoRetIfAsync :: ok.
%% @doc Updates a specific tree node in the tree structure only if it already
%% exists and its data matches the given `DataPattern'.
%%
%% Calling this function is the same as calling `compare_and_swap(StoreId,
%% PathPattern, DataPattern, Data, Extra, Options)' with an empty `Extra' or
%% `Options'.
%%
%% @see compare_and_swap/6.

compare_and_swap(
  StoreId, PathPattern, DataPattern, Data, #{keep_while := _} = Extra) ->
    compare_and_swap(StoreId, PathPattern, DataPattern, Data, Extra, #{});
compare_and_swap(StoreId, PathPattern, DataPattern, Data, Options) ->
    compare_and_swap(StoreId, PathPattern, DataPattern, Data, #{}, Options).

-spec compare_and_swap(
        StoreId, PathPattern, DataPattern, Data, Extra, Options) ->
    Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      DataPattern :: ets:match_pattern(),
      Data :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Extra :: #{keep_while => khepri_machine:keep_while_conds_map()},
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result() | NoRetIfAsync,
      NoRetIfAsync :: ok.
%% @doc Updates a specific tree node in the tree structure only if it already
%% exists and its data matches the given `DataPattern'.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% The `PathPattern' is then modified to include an `#if_data_matches{pattern
%% = DataPattern}' condition on its last component.
%%
%% The provided data is embedded in a {@link khepri_machine:payload_data()} or
%% {@link khepri_machine:payload_sproc()} record before it can be stored in
%% the database.
%%
%% Once the path is normalized to a list of tree node names and conditions,
%% and updated, it calls {@link khepri_machine:put/5}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the node to modify.
%% @param Data the Erlang term or function to store.
%% @param Extra extra options such as `keep_while' conditions.
%% @param Options command options such as the command type.
%%
%% @returns in the case of a synchronous put, an "ok" tuple with a map with one
%% entry, or an "error" tuple; in the case of an asynchronous put, always `ok'
%% (the actual return value may be sent by a message if a correlation ID was
%% specified).
%%
%% @see khepri_machine:put/5.

compare_and_swap(StoreId, PathPattern, DataPattern, Data, Extra, Options) ->
    PathPattern1 = khepri_path:from_string(PathPattern),
    PathPattern2 = khepri_path:combine_with_conditions(
                     PathPattern1, [#if_data_matches{pattern = DataPattern}]),
    do_put(StoreId, PathPattern2, Data, Extra, Options).

-spec do_put(StoreId, PathPattern, Payload, Extra, Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Payload :: khepri_machine:payload() | khepri_machine:data() | fun(),
      Extra :: #{keep_while => khepri_machine:keep_while_conds_map()},
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result() | NoRetIfAsync,
      NoRetIfAsync :: ok.
%% @doc Prepares the payload and calls {@link khepri_machine:put/5}.
%%
%% @private

do_put(StoreId, PathPattern, Payload, Extra, Options) ->
    Payload1 = wrap_payload(Payload),
    khepri_machine:put(StoreId, PathPattern, Payload1, Extra, Options).

-spec wrap_payload(Payload) -> WrappedPayload when
      Payload :: khepri_machine:payload() | khepri_machine:data() | fun(),
      WrappedPayload :: khepri_machine:payload().
%% @doc Ensures the payload is wrapped in one of the internal types.
%%
%% The internal types make sure we avoid any collision between any
%% user-provided terms and internal structures.
%%
%% @param Payload an already wrapped payload, or any term which needs to be
%%        wrapped.
%%
%% @returns the wrapped payload.

wrap_payload(Payload) when ?IS_KHEPRI_PAYLOAD(Payload) ->
    Payload;
wrap_payload(Fun) when is_function(Fun) ->
    #kpayload_sproc{sproc = Fun};
wrap_payload(Data) ->
    #kpayload_data{data = Data}.

-spec clear_payload(PathPattern) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Result :: khepri_machine:result().
%% @doc Clears the payload of an existing specific tree node in the tree
%% structure.
%%
%% Calling this function is the same as calling `clear_payload(StoreId,
%% PathPattern)' with the default store ID.
%%
%% @see clear_payload/2.

clear_payload(PathPattern) ->
    clear_payload(?DEFAULT_RA_CLUSTER_NAME, PathPattern).

-spec clear_payload(StoreId, PathPattern) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Result :: khepri_machine:result().
%% @doc Clears the payload of an existing specific tree node in the tree
%% structure.
%%
%% Calling this function is the same as calling `clear_payload(StoreId,
%% PathPattern, #{}, #{})'.
%%
%% @see clear_payload/4.

clear_payload(StoreId, PathPattern) ->
    clear_payload(StoreId, PathPattern, #{}, #{}).

-spec clear_payload(StoreId, PathPattern, Extra | Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Extra :: #{keep_while => khepri_machine:keep_while_conds_map()},
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result() | NoRetIfAsync,
      NoRetIfAsync :: ok.
%% @doc Clears the payload of an existing specific tree node in the tree
%% structure.
%%
%% Calling this function is the same as calling `clear_payload(StoreId,
%% PathPattern, Extra, Options)' with an empty `Extra' or `Options'.
%%
%% @see clear_payload/4.

clear_payload(StoreId, PathPattern, #{keep_while := _} = Extra) ->
    clear_payload(StoreId, PathPattern, Extra, #{});
clear_payload(StoreId, PathPattern, Options) ->
    clear_payload(StoreId, PathPattern, #{}, Options).

-spec clear_payload(StoreId, PathPattern, Extra, Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Extra :: #{keep_while => khepri_machine:keep_while_conds_map()},
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result() | NoRetIfAsync,
      NoRetIfAsync :: ok.
%% @doc Clears the payload of an existing specific tree node in the tree
%% structure.
%%
%% In other words, the payload is set to `?NO_PAYLOAD'.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% Once the path is normalized to a list of tree node names and conditions,
%% and updated, it calls {@link khepri_machine:put/5}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the node to modify.
%% @param Extra extra options such as `keep_while' conditions.
%% @param Options command options such as the command type.
%%
%% @returns in the case of a synchronous put, an "ok" tuple with a map with one
%% entry, or an "error" tuple; in the case of an asynchronous put, always `ok'
%% (the actual return value may be sent by a message if a correlation ID was
%% specified).
%%
%% @see khepri_machine:put/5.

clear_payload(StoreId, PathPattern, Extra, Options) ->
    khepri_machine:put(StoreId, PathPattern, ?NO_PAYLOAD, Extra, Options).

-spec delete(PathPattern) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Result :: khepri_machine:result().
%% @doc Deletes all tree nodes matching the path pattern.
%%
%% Calling this function is the same as calling `delete(StoreId, PathPattern)'
%% with the default store ID.
%%
%% @see delete/2.

delete(PathPattern) ->
    delete(?DEFAULT_RA_CLUSTER_NAME, PathPattern).

-spec delete
(StoreId, PathPattern) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Result :: khepri_machine:result();
(PathPattern, Options) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result().

%% @doc Deletes all tree nodes matching the path pattern.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`delete(StoreId, PathPattern)'. Calling it is the same as calling
%% `delete(StoreId, PathPattern, #{})'.</li>
%% <li>`delete(PathPattern, Options)'. Calling it is the same as calling
%% `delete(StoreId, PathPattern, Options)' with the default store ID.</li>
%% </ul>
%%
%% @see delete/3.

delete(StoreId, PathPattern) when is_atom(StoreId) ->
    delete(StoreId, PathPattern, #{});
delete(PathPattern, Options) when is_map(Options) ->
    delete(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Options).

-spec delete(StoreId, PathPattern, Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result() | NoRetIfAsync,
      NoRetIfAsync :: ok.
%% @doc Deletes all tree nodes matching the path pattern.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% Once the path is normalized to a list of tree node names and conditions,
%% and updated, it calls {@link khepri_machine:put/5}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the nodes to delete.
%% @param Options command options such as the command type.
%%
%% @returns in the case of a synchronous delete, an "ok" tuple with a map with
%% zero, one or more entries, or an "error" tuple; in the case of an
%% asynchronous put, always `ok' (the actual return value may be sent by a
%% message if a correlation ID was specified).
%%
%% @see khepri_machine:delete/3.

delete(StoreId, PathPattern, Options) ->
    khepri_machine:delete(StoreId, PathPattern, Options).

-spec exists(PathPattern) -> Exists when
      PathPattern :: khepri_path:pattern() | string(),
      Exists :: boolean().
%% @doc Returns `true' if the tree node pointed to by the given path exists,
%% otherwise `false'.
%%
%% Calling this function is the same as calling `exists(StoreId, PathPattern)'
%% with the default store ID.
%%
%% @see exists/2.

exists(PathPattern) ->
    exists(?DEFAULT_RA_CLUSTER_NAME, PathPattern).

-spec exists
(StoreId, PathPattern) -> Exists when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Exists :: boolean();
(PathPattern, Options) -> Exists when
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      Exists :: boolean().
%% @doc Returns `true' if the tree node pointed to by the given path exists,
%% otherwise `false'.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`exists(StoreId, PathPattern)'. Calling it is the same as calling
%% `exists(StoreId, PathPattern, #{})'.</li>
%% <li>`exists(PathPattern, Options)'. Calling it is the same as calling
%% `exists(StoreId, PathPattern, Options)' with the default store ID.</li>
%% </ul>
%%
%% @see exists/3.

exists(StoreId, PathPattern) when is_atom(StoreId) ->
    exists(StoreId, PathPattern, #{});
exists(PathPattern, Options) when is_map(Options) ->
    exists(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Options).

-spec exists(StoreId, PathPattern, Options) -> Exists when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      Exists :: boolean().
%% @doc Returns `true' if the tree node pointed to by the given path exists,
%% otherwise `false'.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% The `PathPattern' must point to a specific tree node and can't match
%% multiple nodes.
%%
%% Once the path is normalized to a list of tree node names and conditions, it
%% calls {@link khepri_machine:get/3}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the nodes to check.
%% @param Options query options such as `favor'.
%%
%% @see khepri_machine:get/3.

exists(StoreId, PathPattern, Options) ->
    Options1 = Options#{expect_specific_node => true},
    case get(StoreId, PathPattern, Options1) of
        {ok, _} -> true;
        _       -> false
    end.

-spec get(PathPattern) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Result :: khepri_machine:result().
%% @doc Returns all tree nodes matching the path pattern.
%%
%% Calling this function is the same as calling `get(StoreId, PathPattern)'
%% with the default store ID.
%%
%% @see get/2.

get(PathPattern) ->
    get(?DEFAULT_RA_CLUSTER_NAME, PathPattern).

-spec get
(StoreId, PathPattern) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Result :: khepri_machine:result();
(PathPattern, Options) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      Result :: khepri_machine:result().
%% @doc Returns all tree nodes matching the path pattern.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`get(StoreId, PathPattern)'. Calling it is the same as calling
%% `get(StoreId, PathPattern, #{})'.</li>
%% <li>`get(PathPattern, Options)'. Calling it is the same as calling
%% `get(StoreId, PathPattern, Options)' with the default store ID.</li>
%% </ul>
%%
%% @see get/3.

get(StoreId, PathPattern) when is_atom(StoreId) ->
    get(StoreId, PathPattern, #{});
get(PathPattern, Options) when is_map(Options) ->
    get(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Options).

-spec get(StoreId, PathPattern, Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      Result :: khepri_machine:result().
%% @doc Returns all tree nodes matching the path pattern.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% Once the path is normalized to a list of tree node names and conditions, it
%% calls {@link khepri_machine:get/3}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the nodes to get.
%% @param Options query options such as `favor'.
%%
%% @returns an "ok" tuple with a map with zero, one or more entries, or an
%% "error" tuple.
%%
%% @see khepri_machine:get/3.

get(StoreId, PathPattern, Options) ->
    khepri_machine:get(StoreId, PathPattern, Options).

-spec get_node_props(PathPattern) -> NodeProps when
      PathPattern :: khepri_path:pattern() | string(),
      NodeProps :: khepri_machine:node_props().
%% @doc Returns the tree node properties associated with the given node path.
%%
%% Calling this function is the same as calling `get_node_props(StoreId,
%% PathPattern)' with the default store ID.
%%
%% @see get_node_props/2.

get_node_props(PathPattern) ->
    get_node_props(?DEFAULT_RA_CLUSTER_NAME, PathPattern).

-spec get_node_props
(StoreId, PathPattern) -> NodeProps when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      NodeProps :: khepri_machine:node_props();
(PathPattern, Options) -> NodeProps when
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      NodeProps :: khepri_machine:node_props().
%% @doc Returns the tree node properties associated with the given node path.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`get_node_props(StoreId, PathPattern)'. Calling it is the same as
%% calling `get_node_props(StoreId, PathPattern, #{})'.</li>
%% <li>`get_node_props(PathPattern, Options)'. Calling it is the same as
%% calling `get_node_props(StoreId, PathPattern, Options)' with the default
%% store ID.</li>
%% </ul>
%%
%% @see get_node_props/3.

get_node_props(StoreId, PathPattern) when is_atom(StoreId) ->
    get_node_props(StoreId, PathPattern, #{});
get_node_props(PathPattern, Options) when is_map(Options) ->
    get_node_props(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Options).

-spec get_node_props(StoreId, PathPattern, Options) -> NodeProps when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      NodeProps :: khepri_machine:node_props().
%% @doc Returns the tree node properties associated with the given node path.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% The `PathPattern' must point to a specific tree node and can't match
%% multiple nodes.
%%
%% Once the path is normalized to a list of tree node names and conditions, it
%% calls {@link khepri_machine:get/3}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the nodes to check.
%% @param Options query options such as `favor'.
%%
%% @returns the tree node properties if the node exists, or throws an
%% exception otherwise.
%%
%% @see khepri_machine:get/3.

get_node_props(StoreId, PathPattern, Options) ->
    Options1 = Options#{expect_specific_node => true},
    case get(StoreId, PathPattern, Options1) of
        {ok, Result} ->
            [{_Path, NodeProps}] = maps:to_list(Result),
            NodeProps;
        Error ->
            throw(Error)
    end.

-spec has_data(PathPattern) -> HasData when
      PathPattern :: khepri_path:pattern() | string(),
      HasData :: boolean().
%% @doc Returns `true' if the tree node pointed to by the given path has data,
%% otherwise `false'.
%%
%% Calling this function is the same as calling `has_data(StoreId,
%% PathPattern)' with the default store ID.
%%
%% @see has_data/2.

has_data(PathPattern) ->
    has_data(?DEFAULT_RA_CLUSTER_NAME, PathPattern).

-spec has_data
(StoreId, PathPattern) -> HasData when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      HasData :: boolean();
(PathPattern, Options) -> HasData when
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      HasData :: boolean().
%% @doc Returns `true' if the tree node pointed to by the given path has data,
%% otherwise `false'.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`has_data(StoreId, PathPattern)'. Calling it is the same as calling
%% `has_data(StoreId, PathPattern, #{})'.</li>
%% <li>`has_data(PathPattern, Options)'. Calling it is the same as calling
%% `has_data(StoreId, PathPattern, Options)' with the default store ID.</li>
%% </ul>
%%
%% @see has_data/3.

has_data(StoreId, PathPattern) when is_atom(StoreId) ->
    has_data(StoreId, PathPattern, #{});
has_data(PathPattern, Options) when is_map(Options) ->
    has_data(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Options).

-spec has_data(StoreId, PathPattern, Options) -> HasData when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      HasData :: boolean().
%% @doc Returns `true' if the tree node pointed to by the given path has data,
%% otherwise `false'.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% The `PathPattern' must point to a specific tree node and can't match
%% multiple nodes.
%%
%% Once the path is normalized to a list of tree node names and conditions, it
%% calls {@link khepri_machine:get/3}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the nodes to check.
%% @param Options query options such as `favor'.
%%
%% @see khepri_machine:get/3.

has_data(StoreId, PathPattern, Options) ->
    try
        NodeProps = get_node_props(StoreId, PathPattern, Options),
        maps:is_key(data, NodeProps)
    catch
        throw:{error, _} ->
            false
    end.

-spec get_data(PathPattern) -> Data when
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:data().
%% @doc Returns the data associated with the given node path.
%%
%% Calling this function is the same as calling `get_data(StoreId,
%% PathPattern)' with the default store ID.
%%
%% @see get_data/2.

get_data(PathPattern) ->
    get_data(?DEFAULT_RA_CLUSTER_NAME, PathPattern).

-spec get_data
(StoreId, PathPattern) -> Data when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Data :: khepri_machine:data();
(PathPattern, Options) -> Data when
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      Data :: khepri_machine:data().
%% @doc Returns the data associated with the given node path.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`get_data(StoreId, PathPattern)'. Calling it is the same as calling
%% `get_data(StoreId, PathPattern, #{})'.</li>
%% <li>`get_data(PathPattern, Options)'. Calling it is the same as calling
%% `get_data(StoreId, PathPattern, Options)' with the default store ID.</li>
%% </ul>
%%
%% @see get_data/3.

get_data(StoreId, PathPattern) when is_atom(StoreId) ->
    get_data(StoreId, PathPattern, #{});
get_data(PathPattern, Options) when is_map(Options) ->
    get_data(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Options).

-spec get_data(StoreId, PathPattern, Options) -> Data when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      Data :: khepri_machine:data().
%% @doc Returns the data associated with the given node path.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% The `PathPattern' must point to a specific tree node and can't match
%% multiple nodes.
%%
%% Once the path is normalized to a list of tree node names and conditions, it
%% calls {@link khepri_machine:get/3}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the nodes to check.
%% @param Options query options such as `favor'.
%%
%% @returns the data if the node has a data payload, or throws an exception
%% otherwise.
%%
%% @see khepri_machine:get/3.

get_data(StoreId, PathPattern, Options) ->
    NodeProps = get_node_props(StoreId, PathPattern, Options),
    case NodeProps of
        #{data := Data} -> Data;
        _               -> throw({no_data, NodeProps})
    end.

-spec has_sproc(PathPattern) -> HasStoredProc when
      PathPattern :: khepri_path:pattern() | string(),
      HasStoredProc :: boolean().
%% @doc Returns `true' if the tree node pointed to by the given path holds a
%% stored procedure, otherwise `false'.
%%
%% Calling this function is the same as calling `has_sproc(StoreId,
%% PathPattern)' with the default store ID.
%%
%% @see has_sproc/2.

has_sproc(PathPattern) ->
    has_sproc(?DEFAULT_RA_CLUSTER_NAME, PathPattern).

-spec has_sproc
(StoreId, PathPattern) -> HasStoredProc when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      HasStoredProc :: boolean();
(PathPattern, Options) -> HasStoredProc when
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      HasStoredProc :: boolean().
%% @doc Returns `true' if the tree node pointed to by the given path holds a
%% stored procedure, otherwise `false'.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`has_sproc(StoreId, PathPattern)'. Calling it is the same as calling
%% `has_sproc(StoreId, PathPattern, #{})'.</li>
%% <li>`has_sproc(PathPattern, Options)'. Calling it is the same as calling
%% `has_sproc(StoreId, PathPattern, Options)' with the default store ID.</li>
%% </ul>
%%
%% @see has_sproc/3.

has_sproc(StoreId, PathPattern) when is_atom(StoreId) ->
    has_sproc(StoreId, PathPattern, #{});
has_sproc(PathPattern, Options) when is_map(Options) ->
    has_sproc(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Options).

-spec has_sproc(StoreId, PathPattern, Options) -> HasStoredProc when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      HasStoredProc :: boolean().
%% @doc Returns `true' if the tree node pointed to by the given path holds a
%% stored procedure, otherwise `false'.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% The `PathPattern' must point to a specific tree node and can't match
%% multiple nodes.
%%
%% Once the path is normalized to a list of tree node names and conditions, it
%% calls {@link khepri_machine:get/3}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the nodes to check.
%% @param Options query options such as `favor'.
%%
%% @see khepri_machine:get/3.

has_sproc(StoreId, PathPattern, Options) ->
    Options1 = Options#{expect_specific_node => true},
    case get(StoreId, PathPattern, Options1) of
        {ok, Result} ->
            [NodeProps] = maps:values(Result),
            maps:is_key(sproc, NodeProps);
        _ ->
            false
    end.

-spec run_sproc(PathPattern, Args) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Args :: list(),
      Result :: any().
%% @doc Runs the stored procedure pointed to by the given path and returns the
%% result.
%%
%% Calling this function is the same as calling `run_sproc(StoreId,
%% PathPattern, Args)' with the default store ID.
%%
%% @see run_sproc/3.

run_sproc(PathPattern, Args) ->
    run_sproc(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Args).

-spec run_sproc
(StoreId, PathPattern, Args) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Args :: list(),
      Result :: any();
(PathPattern, Args, Options) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Args :: list(),
      Options :: khepri_machine:query_options(),
      Result :: any().
%% @doc Runs the stored procedure pointed to by the given path and returns the
%% result.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`run_sproc(StoreId, PathPattern, Args)'. Calling it is the same as
%% calling `run_sproc(StoreId, PathPattern, Args, #{})'.</li>
%% <li>`run_sproc(PathPattern, Args, Options)'. Calling it is the same as
%% calling `run_sproc(StoreId, PathPattern, Args, Options)' with the default
%% store ID.</li>
%% </ul>
%%
%% @see run_sproc/3.

run_sproc(StoreId, PathPattern, Args) when is_atom(StoreId) ->
    run_sproc(StoreId, PathPattern, Args, #{});
run_sproc(PathPattern, Args, Options) when is_map(Options) ->
    run_sproc(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Args, Options).

-spec run_sproc(StoreId, PathPattern, Args, Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Args :: list(),
      Options :: khepri_machine:query_options(),
      Result :: any().
%% @doc Runs the stored procedure pointed to by the given path and returns the
%% result.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% The `PathPattern' must point to a specific tree node and can't match
%% multiple nodes.
%%
%% Once the path is normalized to a list of tree node names and conditions, it
%% calls {@link khepri_machine:get/3}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the nodes to check.
%% @param Args the list of arguments to pass to the stored procedure.
%% @param Options query options such as `favor'.
%%
%% @returns the result of the stored procedure execution.
%%
%% @see khepri_machine:run_sproc/3.

run_sproc(StoreId, PathPattern, Args, Options) ->
    khepri_machine:run_sproc(StoreId, PathPattern, Args, Options).

-spec register_trigger(TriggerId, EventFilter, StoredProcPath) -> Ret when
      TriggerId :: khepri_machine:trigger_id(),
      EventFilter :: khepri_machine:event_filter(),
      StoredProcPath :: khepri_path:path() | string(),
      Ret :: ok | error().
%% @doc Registers a trigger.
%%
%% Calling this function is the same as calling `register_trigger(StoreId,
%% TriggerId, EventFilter, StoredProcPath)' with the default store ID.
%%
%% @see register_trigger/4.

register_trigger(TriggerId, EventFilter, StoredProcPath) ->
    register_trigger(
      ?DEFAULT_RA_CLUSTER_NAME, TriggerId, EventFilter, StoredProcPath).

-spec register_trigger
(StoreId, TriggerId, EventFilter, StoredProcPath) -> Ret when
      StoreId :: khepri:store_id(),
      TriggerId :: khepri_machine:trigger_id(),
      EventFilter :: khepri_machine:event_filter(),
      StoredProcPath :: khepri_path:path() | string(),
      Ret :: ok | error();
(TriggerId, EventFilter, StoredProcPath, Options) -> Ret when
      TriggerId :: khepri_machine:trigger_id(),
      EventFilter :: khepri_machine:event_filter(),
      StoredProcPath :: khepri_path:path() | string(),
      Options :: khepri_machine:command_options(),
      Ret :: ok | error().
%% @doc Registers a trigger.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`register_trigger(StoreId, TriggerId, EventFilter, StoredProcPath)'.
%% Calling it is the same as calling `register_trigger(StoreId, TriggerId,
%% EventFilter, StoredProcPath, #{})'.</li>
%% <li>`register_trigger(TriggerId, EventFilter, StoredProcPath, Options)'.
%% Calling it is the same as calling `register_trigger(StoreId, TriggerId,
%% EventFilter, StoredProcPath, Options)' with the default store ID.</li>
%% </ul>
%%
%% @see register_trigger/5.

register_trigger(StoreId, TriggerId, EventFilter, StoredProcPath)
  when is_atom(StoreId) ->
    register_trigger(StoreId, TriggerId, EventFilter, StoredProcPath, #{});
register_trigger(TriggerId, EventFilter, StoredProcPath, Options)
  when is_map(Options) ->
    register_trigger(
      ?DEFAULT_RA_CLUSTER_NAME, TriggerId, EventFilter, StoredProcPath,
      Options).

-spec register_trigger(
        StoreId, TriggerId, EventFilter, StoredProcPath, Options) ->
    Ret when
      StoreId :: khepri:store_id(),
      TriggerId :: khepri_machine:trigger_id(),
      EventFilter :: khepri_machine:event_filter(),
      StoredProcPath :: khepri_path:path() | string(),
      Options :: khepri_machine:command_options(),
      Ret :: ok | error().
%% @doc Registers a trigger.
%%
%% @param StoreId the name of the Ra cluster.
%% @param TriggerId the name of the trigger.
%% @param EventFilter the event filter used to associate an event with a
%%        stored procedure.
%% @param StoredProcPath the path to the stored procedure to execute when the
%%        corresponding event occurs.
%%
%% @returns `ok' if the trigger was registered, an "error" tuple otherwise.
%%
%% @see khepri_machine:register_trigger/5.

register_trigger(StoreId, TriggerId, EventFilter, StoredProcPath, Options) ->
    khepri_machine:register_trigger(
      StoreId, TriggerId, EventFilter, StoredProcPath, Options).

-spec list(PathPattern) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Result :: khepri_machine:result().
%% @doc Returns all direct child nodes under the given path.
%%
%% Calling this function is the same as calling `list(StoreId, PathPattern)'
%% with the default store ID.
%%
%% @see list/2.

list(PathPattern) ->
    list(?DEFAULT_RA_CLUSTER_NAME, PathPattern).

-spec list
(StoreId, PathPattern) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Result :: khepri_machine:result();
(PathPattern, Options) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      Result :: khepri_machine:result().
%% @doc Returns all direct child nodes under the given path.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`list(StoreId, PathPattern)'. Calling it is the same as calling
%% `list(StoreId, PathPattern, #{})'.</li>
%% <li>`list(PathPattern, Options)'. Calling it is the same as calling
%% `list(StoreId, PathPattern, Options)' with the default store ID.</li>
%% </ul>
%%
%% @see list/3.

list(StoreId, PathPattern) when is_atom(StoreId) ->
    list(StoreId, PathPattern, #{});
list(PathPattern, Options) when is_map(Options) ->
    list(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Options).

-spec list(StoreId, PathPattern, Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Options :: khepri_machine:query_options(),
      Result :: khepri_machine:result().
%% @doc Returns all direct child nodes under the given path.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% Once the path is normalized to a list of tree node names and conditions, it
%% calls {@link khepri_machine:get/3}.
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path (or path pattern) to the nodes to get.
%% @param Options query options such as `favor'.
%%
%% @returns an "ok" tuple with a map with zero, one or more entries, or an
%% "error" tuple.
%%
%% @see khepri_machine:get/3.

list(StoreId, PathPattern, Options) ->
    PathPattern1 = khepri_path:from_string(PathPattern),
    PathPattern2 = [?ROOT_NODE | PathPattern1] ++ [?STAR],
    get(StoreId, PathPattern2, Options).

-spec find(PathPattern, Condition) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Condition :: khepri_path:pattern_component(),
      Result :: khepri_machine:result().
%% @doc Returns all tree nodes matching the path pattern.
%%
%% Calling this function is the same as calling `find(StoreId, PathPattern)'
%% with the default store ID.
%%
%% @see find/3.

find(PathPattern, Condition) ->
    find(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Condition).

-spec find
(StoreId, PathPattern, Condition) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Condition :: khepri_path:pattern_component(),
      Result :: khepri_machine:result();
(PathPattern, Condition, Options) -> Result when
      PathPattern :: khepri_path:pattern() | string(),
      Condition :: khepri_path:pattern_component(),
      Options :: khepri_machine:query_options(),
      Result :: khepri_machine:result().
%% @doc Returns all tree nodes matching the path pattern.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`find(StoreId, PathPattern, Condition)'. Calling it is the same as
%% calling `find(StoreId, PathPattern, Condition, #{})'.</li>
%% <li>`find(PathPattern, Condition, Options)'. Calling it is the same as
%% calling `find(StoreId, PathPattern, Condition, Options)' with the default
%% store ID.</li>
%% </ul>
%%
%% @see find/4.

find(StoreId, PathPattern, Condition) when is_atom(StoreId) ->
    find(StoreId, PathPattern, Condition, #{});
find(PathPattern, Condition, Options) when is_map(Options) ->
    find(?DEFAULT_RA_CLUSTER_NAME, PathPattern, Condition, Options).

-spec find(StoreId, PathPattern, Condition, Options) -> Result when
      StoreId :: store_id(),
      PathPattern :: khepri_path:pattern() | string(),
      Condition :: khepri_path:pattern_component(),
      Options :: khepri_machine:query_options(),
      Result :: khepri_machine:result().
%% @doc Finds tree nodes under `PathPattern' which match the given `Condition'.
%%
%% The `PathPattern' can be provided as a list of node names and conditions or
%% as a string. See {@link khepri_path:from_string/1}.
%%
%% Nodes are searched deeply under the given `PathPattern', not only among
%% direct child nodes.
%%
%% Example:
%% ```
%% %% Find nodes with data under `/:foo/:bar'.
%% Result = khepri:find(
%%            ra_cluster_name,
%%            [foo, bar],
%%            #if_has_data{has_data = true}),
%%
%% %% Here is the content of `Result'.
%% {ok, #{[foo, bar, baz] => #{data => baz_value,
%%                             payload_version => 2,
%%                             child_list_version => 1,
%%                             child_list_length => 0},
%%        [foo, bar, deep, under, qux] => #{data => qux_value,
%%                                          payload_version => 1,
%%                                          child_list_version => 1,
%%                                          child_list_length => 0}}} = Result.
%% '''
%%
%% @param StoreId the name of the Ra cluster.
%% @param PathPattern the path indicating where to start the search from.
%% @param Condition the condition nodes must match to be part of the result.
%%
%% @returns an "ok" tuple with a map with zero, one or more entries, or an
%% "error" tuple.

find(StoreId, PathPattern, Condition, Options) ->
    Condition1 = #if_all{conditions = [?STAR_STAR, Condition]},
    PathPattern1 = khepri_path:from_string(PathPattern),
    PathPattern2 = [?ROOT_NODE | PathPattern1] ++ [Condition1],
    get(StoreId, PathPattern2, Options).

-spec transaction(Fun) -> Ret when
      Fun :: khepri_tx:tx_fun(),
      Ret :: Atomic | Aborted,
      Atomic :: {atomic, khepri_tx:tx_fun_result()},
      Aborted :: khepri_tx:tx_abort().
%% @doc Runs a transaction and returns its result.
%%
%% Calling this function is the same as calling `transaction(StoreId, Fun)'
%% with the default store ID.
%%
%% @see transaction/2.

transaction(Fun) ->
    transaction(?DEFAULT_RA_CLUSTER_NAME, Fun).

-spec transaction
(StoreId, Fun) -> Ret when
      StoreId :: store_id(),
      Fun :: khepri_tx:tx_fun(),
      Ret :: Atomic | Aborted,
      Atomic :: {atomic, khepri_tx:tx_fun_result()},
      Aborted :: khepri_tx:tx_abort();
(Fun, ReadWriteOrOptions) -> Ret when
      Fun :: khepri_tx:tx_fun(),
      ReadWriteOrOptions :: ReadWrite | Options,
      ReadWrite :: ro | rw | auto,
      Options :: khepri_machine:command_options() |
                 khepri_machine:query_options(),
      Ret :: Atomic | Aborted | NoRetIfAsync,
      Atomic :: {atomic, khepri_tx:tx_fun_result()},
      Aborted :: khepri_tx:tx_abort(),
      NoRetIfAsync :: ok.
%% @doc Runs a transaction and returns its result.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`transaction(StoreId, Fun)'. Calling it is the same as calling
%% `transaction(StoreId, Fun, #{})'.</li>
%% <li>`transaction(Fun, Options)'. Calling it is the same as calling
%% `transaction(StoreId, Fun, Options)' with the default store ID.</li>
%% </ul>
%%
%% @see transaction/3.

transaction(StoreId, Fun) when is_function(Fun) ->
    transaction(StoreId, Fun, auto);
transaction(Fun, ReadWriteOrOptions) when is_function(Fun) ->
    transaction(?DEFAULT_RA_CLUSTER_NAME, Fun, ReadWriteOrOptions).

-spec transaction
(StoreId, Fun, ReadWrite) -> Ret when
      StoreId :: store_id(),
      Fun :: khepri_tx:tx_fun(),
      ReadWrite :: ro | rw | auto,
      Ret :: Atomic | Aborted,
      Atomic :: {atomic, khepri_tx:tx_fun_result()},
      Aborted :: khepri_tx:tx_abort();
(StoreId, Fun, Options) -> Ret when
      StoreId :: store_id(),
      Fun :: khepri_tx:tx_fun(),
      Options :: khepri_machine:command_options() |
                 khepri_machine:query_options(),
      Ret :: Atomic | Aborted | NoRetIfAsync,
      Atomic :: {atomic, khepri_tx:tx_fun_result()},
      Aborted :: khepri_tx:tx_abort(),
      NoRetIfAsync :: ok;
(Fun, ReadWrite, Options) -> Ret when
      Fun :: khepri_tx:tx_fun(),
      ReadWrite :: ro | rw | auto,
      Options :: khepri_machine:command_options() |
                 khepri_machine:query_options(),
      Ret :: Atomic | Aborted | NoRetIfAsync,
      Atomic :: {atomic, khepri_tx:tx_fun_result()},
      Aborted :: khepri_tx:tx_abort(),
      NoRetIfAsync :: ok.
%% @doc Runs a transaction and returns its result.
%%
%% This function accepts the following three forms:
%% <ul>
%% <li>`transaction(StoreId, PathPattern, ReadWrite)'. Calling it is the same
%% as calling `transaction(StoreId, PathPattern, ReadWrite, #{})'.</li>
%% <li>`transaction(StoreId, PathPattern, Options)'. Calling it is the same
%% as calling `transaction(StoreId, PathPattern, auto, Options)'.</li>
%% <li>`transaction(PathPattern, ReadWrite, Options)'. Calling it is the same
%% as calling `transaction(StoreId, PathPattern, ReadWrite, Options)' with the
%% default store ID.</li>
%% </ul>
%%
%% @see transaction/4.

transaction(StoreId, Fun, ReadWrite)
  when is_atom(StoreId) andalso is_atom(ReadWrite) ->
    transaction(StoreId, Fun, ReadWrite, #{});
transaction(StoreId, Fun, Options)
  when is_atom(StoreId) andalso is_map(Options) ->
    transaction(StoreId, Fun, auto, Options);
transaction(Fun, ReadWrite, Options)
  when is_atom(ReadWrite) andalso is_map(Options) ->
    transaction(
      ?DEFAULT_RA_CLUSTER_NAME, Fun, ReadWrite, Options).

-spec transaction(StoreId, Fun, ReadWrite, Options) -> Ret when
      StoreId :: store_id(),
      Fun :: khepri_tx:tx_fun(),
      ReadWrite :: ro | rw | auto,
      Options :: khepri_machine:command_options() |
                 khepri_machine:query_options(),
      Ret :: Atomic | Aborted | NoRetIfAsync,
      Atomic :: {atomic, khepri_tx:tx_fun_result()},
      Aborted :: khepri_tx:tx_abort(),
      NoRetIfAsync :: ok.
%% @doc Runs a transaction and returns its result.
%%
%% The `PathPattern' can be provided as native path (a list of node names and
%% conditions) or as a string. See {@link khepri_path:from_string/1}.
%%
%% The `PathPattern' must point to a specific tree node and can't match
%% multiple nodes.
%%
%% Once the path is normalized to a list of tree node names and conditions, it
%% calls {@link khepri_machine:transaction/4}.
%%
%% @see khepri_machine:transaction/4.

transaction(StoreId, Fun, ReadWrite, Options) ->
    khepri_machine:transaction(StoreId, Fun, ReadWrite, Options).

-spec clear_store() -> Result when
      Result :: khepri_machine:result().
%% @doc Wipes out the entire tree.
%%
%% Calling this function is the same as calling `clear_store(StoreId)' with
%% the default store ID.
%%
%% @see clear_store/1.

clear_store() ->
    clear_store(?DEFAULT_RA_CLUSTER_NAME).

-spec clear_store
(StoreId) -> Result when
      StoreId :: store_id(),
      Result :: khepri_machine:result();
(Options) -> Result when
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result().
%% @doc Wipes out the entire tree.
%%
%% This function accepts the following two forms:
%% <ul>
%% <li>`clear_store(StoreId)'. Calling it is the same as calling
%% `clear_store(StoreId, #{})'.</li>
%% <li>`clear_store(Options)'. Calling it is the same as calling
%% `clear_store(StoreId, Options)' with the default store ID.</li>
%% </ul>
%%
%% @see clear_store/2.

clear_store(StoreId) when is_atom(StoreId) ->
    clear_store(StoreId, #{});
clear_store(Options) when is_map(Options) ->
    clear_store(?DEFAULT_RA_CLUSTER_NAME, Options).

-spec clear_store(StoreId, Options) -> Result when
      StoreId :: store_id(),
      Options :: khepri_machine:command_options(),
      Result :: khepri_machine:result().
%% @doc Wipes out the entire tree.
%%
%% @param StoreId the name of the Ra cluster.
%% @param Options command options such as the command type.
%%
%% @returns in the case of a synchronous delete, an "ok" tuple with a map with
%% zero, one or more entries, or an "error" tuple; in the case of an
%% asynchronous put, always `ok' (the actual return value may be sent by a
%% message if a correlation ID was specified).
%%
%% @see delete/3.

clear_store(StoreId, Options) ->
    delete(StoreId, [?STAR], Options).

-spec no_payload() -> ?NO_PAYLOAD.
%% @doc Returns `?NO_PAYLOAD'.
%%
%% This is a helper for cases where using records is inconvenient, like in an
%% Erlang shell.

no_payload() ->
    ?NO_PAYLOAD.

-spec data_payload(Term) -> Payload when
      Term :: khepri_machine:data(),
      Payload :: #kpayload_data{}.
%% @doc Returns `#kpayload_data{data = Term}'.
%%
%% This is a helper for cases where using macros is inconvenient, like in an
%% Erlang shell.

data_payload(Term) ->
    #kpayload_data{data = Term}.

sproc_payload(Fun) when is_function(Fun) ->
    #kpayload_sproc{sproc = Fun};
sproc_payload(#standalone_fun{} = Fun) ->
    #kpayload_sproc{sproc = Fun}.

%% -------------------------------------------------------------------
%% Public helpers.
%% -------------------------------------------------------------------

info() ->
    StoreIds = get_store_ids(),
    case StoreIds of
        [] ->
            io:format("No stores running~n");
        _ ->
            io:format("Running stores:~n"),
            lists:foreach(
              fun(StoreId) ->
                      io:format("  ~ts~n", [StoreId])
              end, StoreIds)
    end.

-spec info(store_id()) -> ok.

info(StoreId) ->
    io:format("~n\033[1;32m== CLUSTER MEMBERS ==\033[0m~n~n", []),
    Nodes = lists:sort([Node || {_, Node} <- members(StoreId)]),
    lists:foreach(fun(Node) -> io:format("~ts~n", [Node]) end, Nodes),

    case khepri_machine:get_keep_while_conds_state(StoreId) of
        {ok, KeepWhileConds} when KeepWhileConds =/= #{} ->
            io:format("~n\033[1;32m== LIFETIME DEPS ==\033[0m~n", []),
            WatcherList = lists:sort(maps:keys(KeepWhileConds)),
            lists:foreach(
              fun(Watcher) ->
                      io:format("~n\033[1m~p depends on:\033[0m~n", [Watcher]),
                      WatchedsMap = maps:get(Watcher, KeepWhileConds),
                      Watcheds = lists:sort(maps:keys(WatchedsMap)),
                      lists:foreach(
                        fun(Watched) ->
                                Condition = maps:get(Watched, WatchedsMap),
                                io:format(
                                  "    ~p:~n"
                                  "        ~p~n",
                                  [Watched, Condition])
                        end, Watcheds)
              end, WatcherList);
        _ ->
            ok
    end,

    case get(StoreId, [?STAR_STAR]) of
        {ok, Result} ->
            io:format("~n\033[1;32m== TREE ==\033[0m~n~n●~n", []),
            Tree = khepri_utils:flat_struct_to_tree(Result),
            khepri_utils:display_tree(Tree);
        _ ->
            ok
    end.
