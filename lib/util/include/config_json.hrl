-ifndef(CONFIG_JSON_HRL).
-define(CONFIG_JSON_HRL, true).

-type type_name() ::
        'bool' |
        {'int', integer(), integer() | 'unbounded'} |
        'ipv4address:port' |
        'ipv6address' |
        'base64' |
        'readable_file' |
        'writable_file' |
        'writable_directory' |
        'string'.

-type ip_address_port() :: {inet:ip4_address(), inet:port_number()}.
-type enum() :: atom().
-type json_value() :: ip_address_port() |
                      enum() |
                      integer() |
                      boolean() |
                      binary() |
                      'null' |
                      float().
-type json_term() ::
        [{binary() | atom(), json_term()}] |
        [json_term()] |
        json_value().

-record(json_type, {
          name    :: type_name(),
          info    :: binary(),
          typical :: json_value(),
          convert :: fun((json_value()) -> json_value()),
          reloadable = true
         }).

-type json_schema() :: [{atom(), #json_type{}}] | [json_schema()].

-type json_name() :: atom() | {atom(), json_value()}.
-type json_path() :: [json_name()].

-endif.
