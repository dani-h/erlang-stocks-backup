%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Daily Stock data grabber/parser %%
%% Author : Robert Petre           %%
%% Group  : Gekko                  %% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(server_daily).
-include("../include/defs.hrl").
-behaviour(gen_server).

%% Only use these 3 exports
-export([start_link/0,run_update/0,stop/0]).

-export([init/1, handle_call/3, handle_cast/2 ,handle_info/2,
         terminate/2, code_change/3]).
		 
start_link() ->
	gen_server:start_link({local,?DAILYSERVER},?MODULE,[], []).

%%
%% Public custom functions
%%	

%% Call once to start updating, it schedules further updates by itself
run_update() ->
	gen_server:call(whereis(serverDaily),{runUpdate,true}).
%% Call to safely stop the gen server
stop() ->
	gen_server:call(whereis(serverDaily),stop).

	
%%
%% gen_serv specific funcs
%%	
	
init([]) -> 
	inets:start(),
	{ok,Pid} = inets:start(ftpc,[{host,"dev.semprog.se"},{port,21}]),
	ftp:user(Pid,"FTPUser","Gekkopass1"),
	ftp:nlist(Pid),
	{ok, {pid,Pid}}.
	
handle_call({runUpdate,true}, _From, {pid,Pid}) ->
	L = parse_file(get_binlist(Pid),[]),
	server_sql:call_daily(L),
	timer:apply_after(15000,server_daily,run_update,[]),
	{reply, {sent,ok}, {pid,Pid}};	
handle_call(stop,_From,{pid,Pid}) ->
	inets:stop(ftpc, Pid),
	{stop, normal, {daily,shutdown_ok}, {pid,null}}.
handle_cast({test}, State) ->
	{noreply, State}.	
%%
%% Private Functions
%%	

parse_file([],RecList) -> RecList;
parse_file([H|T],RecList) -> 
	%%io:format("~p~n",[T]),
	parse_file(T,[parse_line(binary_to_list(H))|RecList]).
	
get_binlist(Pid) -> 
	{ok,Bin} = ftp:recv_bin(Pid, "bihourly201206221430.csv"),
	[_|List] = binary:split(Bin,<<"\r\n">>,[global]),
	lists:flatten(List) -- [<<>>].
	
parse_line(Data) -> [Name,Symbol,Date,CurrPrice,ChangeValue,ChangePercent,PrevClose,Open,Volume,Min,Max|_] = re:split(Data,"[,]",[{return,list}]),
	#dailyStock{name=Name,symbol=Symbol,date=fix_date(Date),currPrice=fix_float(CurrPrice),changeValue=fix_float(ChangeValue),changePercent=fix_float(ChangePercent),prevClose=fix_float(PrevClose),open=fix_float(Open),high=fix_float(Max),low=fix_float(Min),volume=fix_float(Volume)}.

fix_float(String) -> {N,_} = string:to_float(String),
	N.
fix_date(Datetime) -> Datetime -- [$-,$-].	
%%
%% UNUSED FUNCTIONS
handle_info(_Info, State) ->
  {noreply, State}. 
terminate(_Reason, _State) ->
  ok. 
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.