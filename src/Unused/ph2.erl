% Author : Dani Hodovic
% Historical parser V2. Incomplete as it needs to be compatible with the database. 
% For now it contains a test method for spawning
 % mini-processes and receiving messages from those printing it in in the shell.

-module(ph2).
%% -export([main/2]).
-include("../include/defs.hrl").
-compile(export_all).
%% -record(hist_stock, {symbol, date, open, high, low, close, volume}).

% {'EXIT',{badarith,[{erlang,'+',[a,1],[]},
                   % {erl_eval,do_apply,6,[{file,"erl_eval.erl"},{line,573}]},
                   % {erl_eval,expr,5,[{file,"erl_eval.erl"},{line,357}]},
                   % {shell,exprs,7,[{file,"shell.erl"},{line,674}]},
                   % {shell,eval_exprs,7,[{file,"shell.erl"},{line,629}]},
                   % {shell,eval_loop,3,[{file,"shell.erl"},{line,614}]}]}}


% t(URL, Dates, Ticker) ->
	% case catch({ok, {_,_,CSV}} = httpc:request(URL, foo)) of
		% {'EXIT', Error} -> hist_server ! {Ticker, Dates};
		% _ -> 
			% case (string:chr(CSV, $!) > 0) of 
				% false ->	parse_csv({CSV}, Ticker);
				% true -> 	error
			% end
	% end.
%% Main function, the 200 decides at what point of the Tickers_List
%% it should clear the memory, i.e do 200 sequentially and continue
main(Old, Recent) ->
	inets:start(),
%% 	dbload:start(),
	io:format("~nStarting...~n~n"),
	reg(),
	Dates = convert_dates(Old, Recent),
	inets:start(httpc, [{profile, foo}]),
	io:format("Parsing Nasdaq..."),
	Tickers = lists:reverse(nasdaqTickers:get()),
	io:format("Parsing Yahoo...~n"),
	{Z, _} = lists:split(1000, Tickers),
	parse_segment(Z, 800, Dates),
	io:format("Done~n").
	
reg() ->
	case whereis(hist_server) of
		undefined ->
			register(hist_server, self());
		_ -> already_registered
	end.

convert_dates(Old, now) ->
	{{Recent_Year, Recent_Month, Recent_Day}, _Time} = calendar:local_time(),	
	{Old_Year, MonthDay} = lists:split(2, Old),
	{Old_Month, Old_Day} = lists:split(2, MonthDay),
	io:format("Dates From: " ++ Old_Year ++ Old_Month ++ Old_Day ++ "~n"
			 ++ "Dates To: " ++ Recent_Year ++ Recent_Month ++ Recent_Day ++ "~n~n"),
	{{Old_Year, Old_Month, Old_Day}, {Recent_Year, Recent_Month, Recent_Day}};
convert_dates(Old, Recent) ->
	{Old_Year, Old_MonthDay} = lists:split(2, Old),
	{Old_Month, Old_Day} = lists:split(2, Old_MonthDay),
	{Recent_Year, Recent_MonthDay} = lists:split(2, Recent),
	{Recent_Month, Recent_Day} = lists:split(2, Recent_MonthDay),
	io:format("Dates From: " ++ Old_Year ++ Old_Month ++ Old_Day ++ "~n"
			 ++ "Dates To: " ++ Recent_Year ++ Recent_Month ++ Recent_Day ++ "~n~n"),
	{{Old_Year, Old_Month, Old_Day}, {Recent_Year, Recent_Month, Recent_Day}}.

%% parse_segment(Tickers_List :: List, N :: Integer),
%% List is the list of tickers
%% Integer is how big of a list it will work with, before clearing memory
parse_segment(Tickers_List, N, Dates) when length(Tickers_List) > N ->
	{A, B} = lists:split(N, Tickers_List),
	divide_tasks(A, 5, 0, Dates),
	io:format("Segment done~n"),
	inets:stop(httpc, foo),
	inets:start(httpc, [{profile, foo}]),
	parse_segment(B, N, Dates);
parse_segment(Tickers_List, _, Dates) ->
	divide_tasks(Tickers_List, 5, 0, Dates),
	ok.

%% divide_tasks(List :: List, N :: Integer, Amount_Of_Processes :: Integer)
%% List is the tickers_list
%% N is how many tickers it will parse per process
%% Amount counts amount of processes spawned
divide_tasks(List, N, Amount, Dates) when length(List) > N ->
	{A, B} = lists:split(N, List),
	spawn_link(?MODULE, iterate_tickers, [A, Dates]),
	divide_tasks(B, N, Amount + 1, Dates);
divide_tasks(List, _, Amount, Dates) ->
	spawn_link(?MODULE, iterate_tickers, [List, Dates]),
	loop_receive(Amount + 1).

%% loop_receive(Amount_of_spawns :: Integer)
%% Amount_of_spawns is the amount of messages it has to receive
loop_receive(Amount_of_spawns) ->
	process_flag(trap_exit, true),
	loop_receive(Amount_of_spawns, 0).
loop_receive(M, N) ->
	case M == N of 
		true ->
			ok;
		false ->
			receive
				{'EXIT', Pid, normal} ->
					io:format("Finished Pid: ~p~n", [Pid]),
					loop_receive(M, N + 1);
				% {Ticker, Dates} ->
					% io:format("Restarting~n");
				A -> io:format("CatchAll actived~n"),
					io:format("~p~n", [A])
				% after 10000 ->
						% timeout
			end
	end.

%% *****Concurrent subprocesses are described below*****
%% *****Concurrent subprocesses are described below*****
%% *****Concurrent subprocesses are described below*****


%% Iterates the tickers supplised in a list
iterate_tickers([H|T], Dates) ->
	processTicker(H, Dates),
	iterate_tickers(T, Dates);
iterate_tickers([], _Dates) ->
	ok.

%% Processes each ticker by getching the CSV for 
%% the historical data
processTicker(Ticker, Dates) ->
	{_,{Hour,Min,Sec}} = erlang:localtime(),
	io:format("Pid: ~p, Processing Ticker:~p at ~p:~p:~p~n", [self(), Ticker, Hour, Min, Sec]),
	{{Old_Year, Old_Month, Old_Day}, 
	 {Recent_Year, Recent_Month, Recent_Day}} = Dates,
	URL = "http://ichart.yahoo.com/table.csv?s="++Ticker
		++"&a=" ++ Old_Month ++"&b="++ Old_Day ++ "&c=" ++ Old_Year
		++"&d="++ Recent_Month ++ "&e=" ++ Recent_Day ++ "&f="++ Recent_Year
			++"&d=m&ignore=.csv",
	{ok, {_,_,CSV}} = httpc:request(URL, foo),
	case (string:chr(CSV, $!) > 0) of 
		false ->	parse_csv({CSV}, Ticker);
		true -> 	error
	end.


%% Parses a single CSV file and calls iterate_records method to
%% iterate over it and create records
parse_csv(CSV, Ticker) ->
	[_|List] = re:split(tuple_to_list(CSV), "\n",
						[{return,list},{parts,infinity}]),
	All_Records = lists:flatten(iterate_records(List, [], Ticker)),
	Me = self(),
	server_sql:handle_call({historical,All_Records}, Me, none),
	receive
		_Msg -> ok
	end.


% Iterates over records and calls iterate_records function 
% to make the actualy records for each line	
iterate_records([H|T], Acc, Ticker) ->
	String = string:tokens(H, ","),
	case String =/= [] of
	 true -> iterate_records(T, [make_records(H, Ticker)|Acc], Ticker);
	 false -> Acc
	end;
iterate_records([], Acc, _Ticker) -> Acc.

%% Makes the records
make_records(Line, Ticker) ->
	[Date, Open, High, Low, Close, Volume, _] = string:tokens(Line, ","),
	#hist_stock{symbol = Ticker, date = Date, open = Open, high = High,
				low = Low, close = Close, volume = Volume}.
%% 	dbload:insert(Stock).
				
