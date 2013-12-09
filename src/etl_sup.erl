-module(etl_sup).
-behaviour(supervisor).
-export([init/1]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([]).
-compile(export_all).



%% ====================================================================
%% Behavioural functions 
%% ====================================================================

start() ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, []).



%% init/1
%% ====================================================================
init([]) ->
	Nasdaq = {nasdaq,{nasdaq_bridge, start, []},
	      transient,2000,worker,[news_ex]},
%% 
%% 	Database = {database,{server_sql, start_link, []},
%% 	      permanent,2000,worker,[server_daily]},
%% 
%% 	Daily = {daily,{server_daily, start_link, []},
%% 	      permanent,2000,worker,[news_ex]},
%% 	
	News = {news,{news_gen, start, [10000]},
	      permanent,2000,worker,[news_ex]},
	
	Historical = {historical,
				{hist_gen, start, [{"20131201", "20131203"}, 10000]},
	     		permanent,brutal_kill,worker,[hist_ex]},
    {ok,{{one_for_one,0,1}, [Nasdaq, News, Historical]}}.

%% ====================================================================
%% Internal functions
%% ====================================================================

