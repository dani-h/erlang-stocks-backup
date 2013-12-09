-module(nasdaq_bridge).
-behaviour(supervisor_bridge).
-export([init/1, terminate/2]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([]).
-compile(export_all).

start() ->
	supervisor_bridge:start_link({local, ?MODULE}, ?MODULE, []).



%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, {}).

%% init/1 
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/supervisor_bridge.html#Module:init-1">supervisor_bridge:init/1</a>
-spec init(Args :: term()) -> Result :: {ok, Pid :: pid(), State :: term()}
										| ignore
										| {error, Error :: term()}. 
%% ====================================================================
init([]) ->
    case nasdaqTickers:start(30000) of
	{ok, Pid} ->
	    {ok, Pid, #state{}};
	Error ->
	    Error
    end.

%% terminate/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/supervisor_bridge.html#Module:terminate-2">supervisor_bridge:termiante/2</a>
-spec terminate(Reason :: shutdown | term(), State :: term()) -> Any :: term().
%% ====================================================================
terminate(Reason, State) ->
%%     nasdaqTickers:stop(),
    ok.

%% ====================================================================
%% Internal functions
%% ====================================================================


