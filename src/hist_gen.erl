-module(hist_gen).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(AMOUNT_OF_C_PROC, 100).
-define(NUM_OF_RESTARTS, 1).
-record(state, {tickers, con_count, dates}).

%% ====================================================================
%% API functions
%% ====================================================================
-export([]).
-compile(export_all).

%% ====================================================================
%% Behavioural functions 
%% ====================================================================


start(Dates, Sleeptime) ->
	Return = gen_server:start_link({local, ?MODULE}, ?MODULE, [], []),
	historical(Dates),
	timer:apply_interval(Sleeptime, ?MODULE, repeat, []),
	Return.

historical(Dates) ->
	gen_server:call(?MODULE, Dates).

repeat() ->
	Var = gen_server:call(?MODULE, default),
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
handle_call(Dates, _From, State) when State#state.tickers == undefined ->
	{Tickers, NewDates} = start_up(Dates),
	Reply = ok,
	{reply, Reply, #state{tickers = Tickers, con_count = ?AMOUNT_OF_C_PROC - 1, dates = NewDates}};
handle_call(Dates, _From, State) ->
	Reply = already_started,
	{reply, Reply, State}.


%% handle_cast/2
%% ====================================================================
handle_cast(_Msg, State)	->
	{noreply, State}.

%% handle_info/2
%% ====================================================================
handle_info({'EXIT', _Pid, {badmatch, Ticker, Restarts}}, State) ->
	restart_worker(Ticker, State#state.dates, Restarts),
	{noreply, State};
handle_info({catch_all, Msg}, State) ->
	common_methods:print(?MODULE, "Catch all, report it to Dani! Error message: ", Msg),
%% 	restart_worker(Ticker, State#state.dates, Restarts),
	{noreply, State};

handle_info({'EXIT', _Pid, {normal, Ticker}}, State) 
  when State#state.con_count < 1 , length(State#state.tickers) > ?AMOUNT_OF_C_PROC ->
	{Segment, _Rest} = lists:split(?AMOUNT_OF_C_PROC, State#state.tickers),
	spawn_workers(Segment, State#state.dates),
	NewState = #state{con_count = ?AMOUNT_OF_C_PROC - 1, 
					  dates = State#state.dates,  
					  tickers = State#state.tickers -- [Ticker]},
	common_methods:print(?MODULE, "Finished segment of: ", ?AMOUNT_OF_C_PROC),
	{noreply, NewState};
handle_info({'EXIT', _Pid, {normal, Ticker}}, State)
  when State#state.con_count < 1 ->
	NewState = #state{con_count = ?AMOUNT_OF_C_PROC - 1, 
					  dates = State#state.dates,  
					  tickers = State#state.tickers -- [Ticker]},
	common_methods:print(?MODULE, "Processing last segment of: ", length(NewState#state.tickers)),
	spawn_workers(NewState#state.tickers, State#state.dates),
	{noreply, NewState};
handle_info({'EXIT', Pid, {normal, Ticker}}, State) ->	
%% 	io:format("Handled ticker:~p, Left:~p~n", [Ticker, length(State#state.tickers)]),
	NewState = #state{con_count = State#state.con_count - 1, 
					  dates = State#state.dates,  
					  tickers = State#state.tickers -- [Ticker]},
	case NewState#state.tickers == [] of
		false ->
			{noreply, NewState};
		true ->
			common_methods:print(?MODULE, "Finished"),
			io:format("Finished~n"),
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

start_up(D) ->
	case is_tuple(D) of
		true ->
			{Old, Recent} = D,
			Dates = convert_dates(Old, Recent);
		false ->
			Dates = convert_dates(default)
	end,
	inets:start(),
	process_flag(trap_exit, true),
	common_methods:print(?MODULE, "Reading tickers..."),
	Tickers = common_methods:read_existing_file(),
	{A, _} = lists:split(202, Tickers),
	{Segment, _Rest} = lists:split(?AMOUNT_OF_C_PROC, Tickers),
	spawn_workers(Segment, Dates),
	{Tickers, Dates}.

spawn_workers([One_Ticker|Rest], Dates) ->
	spawn_link(hist_worker, process_ticker, [One_Ticker, Dates, 0]),
	spawn_workers(Rest, Dates);
spawn_workers([], _Dates) ->
	ok.

restart_worker(Ticker, Dates, N) ->
	case N == ?NUM_OF_RESTARTS of
		true ->
			common_methods:print(?MODULE, "This ticker reached max amount of restarts: ", Ticker),
			?MODULE ! {'EXIT', restart_pid, {normal, Ticker}};
		false ->
			common_methods:print(?MODULE, "This ticker is being restarted: ", Ticker),
			spawn_link(hist_worker, process_ticker, [Ticker, Dates, N + 1])
	end.

%% restart_inets() ->
%% 	inets:stop(httpc, historical),
%% 	inets:start(httpc, [{profile, historical}]).


convert_dates(default) ->
	{{Year, Month, Day}, {_,_,_}} = calendar:local_time(),
	Recent_Return = date_helper(integer_to_list(Year) 
									++ integer_to_list(Month) ++ integer_to_list(Day)),
	case Day < 3 of
		false ->
			Old_Return = date_helper(integer_to_list(Year) ++
										 integer_to_list(Month) ++ integer_to_list(Day - 3));
		true ->
			Old_Return = date_helper(integer_to_list(Year)++
										 integer_to_list(Month - 1) ++ integer_to_list(28))
	end,
	case Old_Return < Recent_Return of
		true ->
			{Old_Return, Recent_Return};
		false ->
			throw("Invalid dates, the second argument must be the recent date")
	end.

convert_dates(Old, Recent) ->
	Old_Return = date_helper(Old),
	Recent_Return = date_helper(Recent),
	case Old_Return < Recent_Return of
		true -> 
			{Old_Return, Recent_Return};
		false ->
			throw("Invalid dates, the second argument must be the recent date")
	end.

date_helper(Date) ->
	{Year_String, MonthDay_String} = lists:split(4, Date),
	{Month_String, Day_String} = lists:split(2, MonthDay_String),
	Year = list_to_integer(Year_String),
	Month = list_to_integer(Month_String),
	Day = list_to_integer(Day_String),
	case calendar:valid_date(Year, Month, Day) of
		false -> throw("Invalid dates");
		true -> 
			Return_Year = integer_to_list(Year),
			Return_Day = integer_to_list(Day),
			if 
				Month == 1 -> Return_Month = "12";
				true -> Return_Month = integer_to_list(Month - 1)
			end,
			{Return_Year, Return_Month, Return_Day}
	end.