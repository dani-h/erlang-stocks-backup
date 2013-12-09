-module(hist_worker).
%% Test Comment
-include("../include/defs.hrl").
-compile(export_all).
-define(AMOUNT, 100).



%% Processes each ticker by getching the CSV for 
%% the historical data
process_ticker(Ticker, Dates, Restarts) ->
	{_,{Hour,Min,Sec}} = erlang:localtime(),
	{{Old_Year, Old_Month, Old_Day}, 
	 {Recent_Year, Recent_Month, Recent_Day}} = Dates,
	URL = "http://ichart.yahoo.com/table.csv?s="++Ticker
		++"&a=" ++ Old_Month ++"&b="++ Old_Day ++ "&c=" ++ Old_Year
		++"&d="++ Recent_Month ++ "&e=" ++ Recent_Day ++ "&f="++ Recent_Year
			++"&d=m&ignore=.csv",
	try
		{ok, {_,_,CSV}} = httpc:request(get, {URL, []}, [{connect_timeout, 1000}, {timeout, 30000}], []),
	
		case (string:chr(CSV, $!) > 0) of 
			false ->	
%% 				io:format("Pid: ~p, Processing Ticker:~p at ~p:~p:~p~n", [self(), Ticker, Hour, Min, Sec]),
				parse_csv({CSV}, Ticker);
%% 				io:format("Succeded, Ticker: ~p~n", [Ticker]);
			true -> 
				common_methods:print(?MODULE, "Yahoo says ticker not found: ", Ticker)
		end,
		exit({normal, Ticker})
	catch
		error:{badmatch,{error,socket_closed_remotely}} -> 
%% 			io:format("Socket closed remotely, ticker: ~p~n", [Ticker]),
			exit({badmatch, Ticker, Restarts});
		error:{badmatch, {error, {failed_connect,_}}} ->
%% 			io:format("Failed connect, ticker: ~p~n", [Ticker]),
			exit({badmatch, Ticker, Restarts});
		error:{badmatch,{error,timeout}} ->
%% 			io:format("Timed out, ticker:~p~n", [Ticker]),
			exit({badmatch, Ticker, Restarts})
%% 		error:Catch_all -> 
%% 			io:format("~nIn ex, catch_all, Msg: ~p~n", [Catch_all]),
%% 			throw("Dani look here : " ++ Ticker),
%% 			exit({catch_all, Catch_all})
	end.
	

%% Parses a single CSV file and calls iterate_records method to
%% iterate over it and create records
parse_csv(CSV, Ticker) ->
	[_|Relevant_Info] = re:split(tuple_to_list(CSV), "\n",
						[{return,list},{parts,infinity}]),
%% 	{ok, Pid} = odbc:connect(?ConnectStr,[{timeout, 2000}]),
	Pid = lol,
	iterate_records(Relevant_Info, [], Ticker, Pid).
%% 	odbc:disconnect(Pid).

% Iterates over records and calls iterate_records function 
% to make the actualy records for each line	
iterate_records(List, Acc, Ticker, Pid) when length(Acc) == ?AMOUNT ->
%% 	_Result = odbc:sql_query(Pid, lists:flatten(Acc)),
	iterate_records(List, [], Ticker, Pid);
iterate_records([H|T], Acc, Ticker, Pid) ->
	case H == [] of
		true -> 
			ok;
%% 			io:format("~p~n", [Acc]);
%% 			Result = odbc:sql_query(Pid, lists:flatten(Acc));
		false ->
			iterate_records(T, [make_records(H, Ticker)|Acc], Ticker, Pid)
	end.

%% Makes the records
make_records(Line, Ticker) ->
	% io:format("~p~n", Line).
	[Date, Open, High, Low, Close, Volume, _] = string:tokens(Line, ","),
	_E = "EXEC s_addHistorical " ++
	"@Symbol='" ++ Ticker ++ "'," ++
	"@Date='" ++ Date ++ "'," ++
	"@Open=" ++ Open ++ "," ++
	"@Close=" ++ Close ++ "," ++
	"@MaxPrice=" ++ High ++ "," ++
	"@MinPrice=" ++ Low ++ "," ++
	"@Volume=" ++ Volume ++ ";".

