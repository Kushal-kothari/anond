ERL=$(shell which erl)
ERLC=$(shell which erlc)
ERL_TOP=$(ERL:%/bin/erl=%)
ifeq ($(RELEASE), true)
    ERLC_FLAGS:=-Werror -I ../..
else
    ERLC_FLAGS:=-I ../.. +debug_info -Ddebug
endif
ERL_SOURCES:=$(wildcard *.erl)
ERL_OBJECTS:=$(ERL_SOURCES:%.erl=../ebin/%.beam)
ERL_HEADERS:=$(wildcard *.hrl) $(wildcard ../../common/include/*.hrl) $(wildcard ../../ds/include/*.hrl) $(wildcard ../../node/include/*.hrl) $(wildcard ../../procket/include/*.hrl) $(wildcard ../../salt/include/*.hrl) $(wildcard ../../tunctl/include/*.hrl) $(wildcard ../../util/include/*.hrl)
DIALYZER=dialyzer
