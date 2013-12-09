-module(news_gen).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(AMOUNT_OF_C_PROC, 100).
-define(NUM_OF_RESTARTS, 1).
-record(state, {tickers, con_count}).

%% ====================================================================
%% API functions
%% ====================================================================
-export([]).
-compile(export_all).

%% ====================================================================
%% Behavioural functions 
%% ====================================================================

start(Sleeptime) ->
	Return = gen_server:start_link({local, ?MODULE}, ?MODULE, [], []),
	repeat(),
	timer:apply_interval(Sleeptime, ?MODULE, repeat, []),
	Return.

repeat() ->
	Var = gen_server:call(?MODULE, start),
	case Var of
		already_started ->
			timer:sleep(60000),
			repeat();
		_ ->
			ok
	end.

%% init/1
%% ====================================================================

init([]) ->
	{ok, #state{}}.

%% handle_call/3
%% ====================================================================
handle_call(start, _From, State) when State#state.tickers == undefined ->
	Tickers = start_up(),
	Reply = ok,
	{reply, Reply, #state{tickers = Tickers, con_count = ?AMOUNT_OF_C_PROC - 1}};
handle_call(start, _From, State) ->
	Reply = already_started,
	{reply, Reply, State}.


%% handle_cast/2
%% ====================================================================
handle_cast(Msg, State) ->
	{noreply, State}.
	
%% handle_info/2
%% ====================================================================
handle_info({'EXIT', _Pid, {badmatch, Ticker, Restarts}}, State) ->
	restart_worker(Ticker,  Restarts),
	{noreply, State};
handle_info({'EXIT', _Pid, {catch_all, Msg}}, State) ->

	{noreply, State};


handle_info({'EXIT', _Pid, {normal, Ticker}}, State) 
  when State#state.con_count < 1 , length(State#state.tickers) > ?AMOUNT_OF_C_PROC ->
	common_methods:print(?MODULE, "Finished segment of: ", ?AMOUNT_OF_C_PROC),
	{Segment, _Rest} = lists:split(?AMOUNT_OF_C_PROC, State#state.tickers),
	spawn_workers(Segment),
	NewState = #state{con_count = ?AMOUNT_OF_C_PROC - 1, 
					  tickers = State#state.tickers -- [Ticker]},
	{noreply, NewState};
handle_info({'EXIT', _Pid, {normal, Ticker}}, State)
  when State#state.con_count < 1 ->
	NewState = #state{con_count = ?AMOUNT_OF_C_PROC - 1, 
					  tickers = State#state.tickers -- [Ticker]},
	common_methods:print(?MODULE, "Processing last segment of: ", length(NewState#state.tickers)),
	spawn_workers(NewState#state.tickers),
	{noreply, NewState};
handle_info({'EXIT', _Pid, {normal, Ticker}}, State) ->
	NewState = #state{con_count = State#state.con_count - 1, 
					  tickers = State#state.tickers -- [Ticker]},
	case NewState#state.tickers == [] of
		false ->
			{noreply, NewState};
		true ->
			common_methods:print(?MODULE, "Finishing"),
			{noreply, #state{}}
	end.


%% terminate/2
%% ====================================================================
terminate(Reason, State) ->
	ok.


%% code_change/3
%% ====================================================================
code_change(OldVsn, State, Extra) ->
	{ok, State}.


%% ====================================================================
%% Internal functions
%% ====================================================================

start_up() ->
	inets:start(),
	process_flag(trap_exit, true),
	common_methods:print(?MODULE, "Starting..."),
	Tickers = common_methods:read_existing_file(),
	{A, _} = lists:split(202, Tickers),
	{Segment, _Rest} = lists:split(?AMOUNT_OF_C_PROC, Tickers),
	spawn_workers(Segment),
	Tickers.

spawn_workers([One_Ticker|Rest]) ->
	spawn_link(news_worker, process_ticker, [One_Ticker, 0]),
	spawn_workers(Rest);
spawn_workers([]) ->
	ok.

restart_worker(Ticker, N) ->
	case N > ?NUM_OF_RESTARTS of
		true ->
			common_methods:print(?MODULE, "This ticker reached max amount of restarts: ", Ticker),
			?MODULE ! {'EXIT', restart_pid, {normal, Ticker}};
		false ->
			common_methods:print(?MODULE, "This ticker is being restarted: ", Ticker),
			spawn_link(news_worker, process_ticker, [Ticker, N + 1])
	end.
%% restart_inets() ->
%% 	inets:stop(httpc, news),
%% 	inets:start(httpc, [{profile, news}]).


