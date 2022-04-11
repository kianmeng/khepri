%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright (c) 2021-2022 VMware, Inc. or its affiliates.  All rights reserved.
%%

-module(khepri_clustering).

-include_lib("kernel/include/logger.hrl").

-include("include/khepri.hrl").
-include("src/internal.hrl").

%% For internal use only.
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
         forget_store_ids/0]).

%% -------------------------------------------------------------------
%% Database management.
%% -------------------------------------------------------------------

-spec start() -> {ok, khepri:store_id()} | {error, any()}.

start() ->
    case application:ensure_all_started(ra) of
        {ok, _} ->
            RaSystem = default,
            case ra_system:start_default() of
                {ok, _}                       -> start(RaSystem);
                {error, {already_started, _}} -> start(RaSystem);
                {error, _} = Error            -> Error
            end;
        {error, _} = Error ->
            Error
    end.

-spec start(atom()) ->
    {ok, khepri:store_id()} | {error, any()}.

start(RaSystem) ->
    start(RaSystem, ?DEFAULT_RA_CLUSTER_NAME, ?DEFAULT_RA_FRIENDLY_NAME).

-spec start(atom(), ra:cluster_name(), string()) ->
    {ok, khepri:store_id()} | {error, any()}.

start(RaSystem, ClusterName, FriendlyName) ->
    case application:ensure_all_started(khepri) of
        {ok, _} ->
            case ensure_started(RaSystem, ClusterName, FriendlyName) of
                ok ->
                    ok = remember_store_id(ClusterName),
                    {ok, ClusterName};
                Error ->
                    Error
            end;
        Error ->
            Error
    end.

ensure_started(RaSystem, ClusterName, FriendlyName) ->
    ThisNode = node(),
    ThisMember = node_to_member(ClusterName, ThisNode),
    ?LOG_DEBUG(
       "Check if a local Ra server is running for cluster \"~s\"",
       [ClusterName],
       #{domain => [khepri, clustering]}),
    case whereis(ClusterName) of
        undefined ->
            ?LOG_DEBUG(
               "No local Ra server running for cluster \"~s\", "
               "try to restart it",
               [ClusterName],
               #{domain => [khepri, clustering]}),
            Lock = {ClusterName, self()},
            global:set_lock(Lock),
            Ret = case ra:restart_server(RaSystem, ThisMember) of
                      {error, Reason}
                        when Reason == not_started orelse
                             Reason == name_not_registered ->
                          ?LOG_DEBUG(
                             "Ra cluster not running, try to start it",
                             [],
                             #{domain => [khepri, clustering]}),
                          do_start(
                            RaSystem, ClusterName, FriendlyName,
                            [ThisMember]);
                      ok ->
                          ok;
                      {error, {already_started, _}} ->
                          ok;
                      _ ->
                          ok
                  end,
            global:del_lock(Lock),
            Ret;
        _ ->
            ?LOG_DEBUG(
               "Local Ra server running, part of cluster \"~s\"",
               [ClusterName],
               #{domain => [khepri, clustering]}),
            ok
    end.

do_start(RaSystem, ClusterName, FriendlyName, Members) ->
    RaServerConfigs = [make_ra_server_config(
                         ClusterName, FriendlyName, Member, Members)
                       || Member <- Members],
    ?LOG_DEBUG(
       "Starting a cluster, named \"~s\", with the following Ra server "
       "configuration:~n~p",
       [ClusterName, hd(RaServerConfigs)],
       #{domain => [khepri, clustering]}),
    case ra:start_cluster(RaSystem, RaServerConfigs) of
        {ok, Started, _} ->
            ?LOG_DEBUG(
               "Started Ra server for cluster \"~s\" on ~p",
               [ClusterName, Started],
               #{domain => [khepri, clustering]}),
            ok;
        {error, cluster_not_formed} = Error ->
            ?LOG_ERROR(
               "Failed to start Ra server for cluster \"~s\" using the "
               "following Ra server configuration:~n~p",
               [ClusterName, hd(RaServerConfigs)],
               #{domain => [khepri, clustering]}),
            Error
    end.

add_member(RaSystem, NewNode) ->
    add_member(
      RaSystem, ?DEFAULT_RA_CLUSTER_NAME, ?DEFAULT_RA_FRIENDLY_NAME,
      NewNode).

add_member(RaSystem, ClusterName, FriendlyName, NewNode) ->
    ?LOG_DEBUG(
       "Querying members of cluster \"~s\"",
       [ClusterName],
       #{domain => [khepri, clustering]}),
    case members(ClusterName) of
        ExistingMembers when ExistingMembers =/= [] ->
            NewMember = node_to_member(ClusterName, NewNode),
            case lists:member(NewMember, ExistingMembers) of
                false ->
                    start_ra_server_and_add_member(
                      RaSystem, ClusterName, FriendlyName, ExistingMembers,
                      NewMember);
                true ->
                    ?LOG_DEBUG(
                       "Member ~p is already part of cluster \"~s\"",
                       [NewMember, ClusterName],
                       #{domain => [khepri, clustering]}),
                    ok
            end;
        [] ->
            ?LOG_ERROR(
               "Failed to query members of cluster \"~s\"",
               [ClusterName],
               #{domain => [khepri, clustering]}),
            {error, failed_to_query_cluster_members}
    end.

start_ra_server_and_add_member(
  RaSystem, ClusterName, FriendlyName, ExistingMembers, NewMember) ->
    Lock = {ClusterName, self()},
    global:set_lock(Lock),
    RaServerConfig = make_ra_server_config(
                       ClusterName, FriendlyName, NewMember, ExistingMembers),
    ?LOG_DEBUG(
       "Adding member ~p to cluster \"~s\" with the following "
       "configuraton:~n~p",
       [NewMember, ClusterName, RaServerConfig],
       #{domain => [khepri, clustering]}),
    case ra:start_server(RaSystem, RaServerConfig) of
        ok ->
            %% TODO: Take the timeout as an argument (+ have a default).
            Timeout = 30000,
            Ret = do_add_member(
                    ClusterName, ExistingMembers, NewMember, Timeout),
            global:del_lock(Lock),
            Ret;
        Error ->
            global:del_lock(Lock),
            ?LOG_ERROR(
               "Failed to start member ~p, required to add it to "
               "cluster \"~s\": ~p",
               [NewMember, ClusterName, Error],
               #{domain => [khepri, clustering]}),
            Error
    end.

do_add_member(ClusterName, ExistingMembers, NewMember, Timeout) ->
    T0 = erlang:monotonic_time(),
    Ret = ra:add_member(ExistingMembers, NewMember),
    case Ret of
        {ok, _, _} ->
            ok;
        Error when Timeout >= 0 ->
            ?LOG_NOTICE(
               "Failed to add member ~p to cluster \"~s\": ~p; "
               "will retry for ~b milliseconds",
               [NewMember, ClusterName, Error, Timeout],
               #{domain => [khepri, clustering]}),
            timer:sleep(500),
            T1 = erlang:monotonic_time(),
            TDiff = erlang:convert_time_unit(T1 - T0, native, millisecond),
            TimeLeft = Timeout - TDiff,
            do_add_member(
              ClusterName, ExistingMembers, NewMember, TimeLeft);
        Error ->
            ?LOG_ERROR(
               "Failed to add member ~p to cluster \"~s\": ~p; "
               "aborting",
               [NewMember, ClusterName, Error],
               #{domain => [khepri, clustering]}),
            Error
    end.

remove_member(NodeToRemove) ->
    remove_member(?DEFAULT_RA_CLUSTER_NAME, NodeToRemove).

remove_member(ClusterName, NodeToRemove) ->
    ?LOG_DEBUG(
       "Querying members of cluster \"~s\"",
       [ClusterName],
       #{domain => [khepri, clustering]}),
    case members(ClusterName) of
        ExistingMembers when ExistingMembers =/= [] ->
            MemberToRemove = node_to_member(ClusterName, NodeToRemove),
            case lists:member(MemberToRemove, ExistingMembers) of
                true ->
                    do_remove_member(
                      ClusterName, ExistingMembers, MemberToRemove);
                false ->
                    ?LOG_DEBUG(
                       "Member ~p is not part of cluster \"~s\"",
                       [MemberToRemove, ClusterName],
                       #{domain => [khepri, clustering]}),
                    ok
            end;
        [] ->
            ?LOG_ERROR(
               "Failed to query members of cluster \"~s\"",
               [ClusterName],
               #{domain => [khepri, clustering]}),
            {error, failed_to_query_cluster_members}
    end.

do_remove_member(ClusterName, ExistingMembers, MemberToRemove) ->
    case ra:remove_member(ExistingMembers, MemberToRemove) of
        {ok, _, _} ->
            ok;
        Error ->
            ?LOG_ERROR(
               "Failed to remove member ~p from cluster \"~s\": ~p; "
               "aborting",
               [MemberToRemove, ClusterName, Error],
               #{domain => [khepri, clustering]}),
            Error
    end.

reset(RaSystem, ClusterName) ->
    ThisNode = node(),
    ThisMember = node_to_member(ClusterName, ThisNode),
    ?LOG_DEBUG(
       "Resetting member ~p in cluster \"~s\"",
       [ThisMember, ClusterName],
       #{domain => [khepri, clustering]}),
    ra:force_delete_server(RaSystem, ThisMember).

members(ClusterName) ->
    Fun = fun ra:members/1,
    do_query_members(ClusterName, Fun).

locally_known_members(ClusterName) ->
    Fun = fun(CN) -> ra:members({local, CN}) end,
    do_query_members(ClusterName, Fun).

do_query_members(ClusterName, Fun) ->
    ThisNode = node(),
    ThisMember = node_to_member(ClusterName, ThisNode),
    ?LOG_DEBUG(
       "Query members in cluster \"~s\"",
       [ClusterName],
       #{domain => [khepri, clustering]}),
    case Fun(ThisMember) of
        {ok, Members, _} ->
            ?LOG_DEBUG(
               "Found the following members in cluster \"~s\": ~p",
               [ClusterName, Members],
               #{domain => [khepri, clustering]}),
            Members;
        Error ->
            ?LOG_WARNING(
               "Failed to query members in cluster \"~s\": ~p",
               [ClusterName, Error],
               #{domain => [khepri, clustering]}),
            []
    end.

nodes(ClusterName) ->
    [Node || {_, Node} <- members(ClusterName)].

locally_known_nodes(ClusterName) ->
    [Node || {_, Node} <- locally_known_members(ClusterName)].

node_to_member(ClusterName, Node) ->
    {ClusterName, Node}.

make_ra_server_config(ClusterName, FriendlyName, Member, Members) ->
    UId = ra:new_uid(ra_lib:to_binary(ClusterName)),
    #{cluster_name => ClusterName,
      id => Member,
      uid => UId,
      friendly_name => FriendlyName,
      initial_members => Members,
      log_init_args => #{uid => UId},
      machine => {module, khepri_machine, #{store_id => ClusterName}}}.

-define(PT_STORE_IDS, {khepri, store_ids}).

remember_store_id(ClusterName) ->
    StoreIds = persistent_term:get(?PT_STORE_IDS, #{}),
    StoreIds1 = StoreIds#{ClusterName => true},
    persistent_term:put(?PT_STORE_IDS, StoreIds1),
    ok.

-spec get_store_ids() -> [khepri:store_id()].

get_store_ids() ->
    maps:keys(persistent_term:get(?PT_STORE_IDS, #{})).

-spec forget_store_ids() -> ok.
%% @doc Clears the remembered store IDs.
%%
%% @private

forget_store_ids() ->
    _ = persistent_term:erase(?PT_STORE_IDS),
    ok.
