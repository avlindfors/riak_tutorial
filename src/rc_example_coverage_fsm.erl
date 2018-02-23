-module(rc_example_coverage_fsm).

-behavior(riak_core_coverage_fsm).

-export([
    start_link/4,
    init/2,
    process_results/2,
    finish/2
]).


start_link(ReqId, ClientPid, Request, Timeout) ->
    riak_core_coverage_fsm:start_link(
        ?MODULE, {pid, ReqId, ClientPid},
        [Request, Timeout]
    ).

init({pid, ReqId, ClientPid}, [Request, Timeout]) ->
    lager:info("Starting coverage request ~p ~p", [ReqId, Request]),

    State = #{
        req_id => ReqId,
        from => ClientPid,
        request => Request,
        accum => []},

    {Request, allup, 1, 1, rc_example,
        rc_example_vnode_master, Timeout,
        riak_core_coverage_plan, State}.

process_results({{_ReqId, {_Partition, _Node}}, []}, State) ->
    {done, State};
process_results({{_ReqId, {Partition, Node}}, Data},
    State = #{accum := Accum}) ->
    NewAccum = [ {Partition, Node, Data} | Accum],
    {done, State#{accum => NewAccum}}.

finish(clean, State = #{req_id := ReqId, from := From, accum := Accum}) ->
    lager:info("Finished coverage request ~p", [ReqId]),

    From ! {ReqId, {ok, Accum}},
    {stop, normal, State};
finish({error, Reason}, State = #{req_id := ReqId, from := From, accum := Accum}) ->
    lager:warning("Coverage query failed! Reason: ~p", [Reason]),
    From ! {ReqId, {partial, Reason, Accum}},
    {stop, normal, State}.