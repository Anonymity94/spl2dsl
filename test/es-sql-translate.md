
```json
POST /_sql/translate
{
  "query": "SELECT * FROM kibana_sample_data_logs where request='342342' and ((message>23 or message<= 233) and url='3443') and agent!='msewef' order by bytes desc",
  "fetch_size": 10
}
```

```json
{
  "size" : 10,
  "query" : {
    "bool" : {
      "must" : [
        {
          "bool" : {
            "must" : [
              {
                "term" : {
                  "request.keyword" : {
                    "value" : "342342",
                    "boost" : 1.0
                  }
                }
              },
              {
                "bool" : {
                  "must" : [
                    {
                      "bool" : {
                        "should" : [
                          {
                            "range" : {
                              "message" : {
                                "from" : 23,
                                "to" : null,
                                "include_lower" : false,
                                "include_upper" : false,
                                "boost" : 1.0
                              }
                            }
                          },
                          {
                            "range" : {
                              "message" : {
                                "from" : null,
                                "to" : 233,
                                "include_lower" : false,
                                "include_upper" : true,
                                "boost" : 1.0
                              }
                            }
                          }
                        ],
                        "adjust_pure_negative" : true,
                        "boost" : 1.0
                      }
                    },
                    {
                      "term" : {
                        "url.keyword" : {
                          "value" : "3443",
                          "boost" : 1.0
                        }
                      }
                    }
                  ],
                  "adjust_pure_negative" : true,
                  "boost" : 1.0
                }
              }
            ],
            "adjust_pure_negative" : true,
            "boost" : 1.0
          }
        },
        {
          "bool" : {
            "must_not" : [
              {
                "term" : {
                  "agent.keyword" : {
                    "value" : "msewef",
                    "boost" : 1.0
                  }
                }
              }
            ],
            "adjust_pure_negative" : true,
            "boost" : 1.0
          }
        }
      ],
      "adjust_pure_negative" : true,
      "boost" : 1.0
    }
  },
  "_source" : {
    "includes" : [
      "agent",
      "bytes",
      "clientip",
      "extension",
      "host",
      "index",
      "ip",
      "machine.os",
      "machine.ram",
      "memory",
      "message",
      "phpmemory",
      "request",
      "response",
      "tags",
      "url"
    ],
    "excludes" : [ ]
  },
  "docvalue_fields" : [
    {
      "field" : "@timestamp",
      "format" : "epoch_millis"
    },
    {
      "field" : "event.dataset"
    },
    {
      "field" : "geo.coordinates"
    },
    {
      "field" : "geo.dest"
    },
    {
      "field" : "geo.src"
    },
    {
      "field" : "geo.srcdest"
    },
    {
      "field" : "referer"
    },
    {
      "field" : "timestamp",
      "format" : "epoch_millis"
    },
    {
      "field" : "utc_time",
      "format" : "epoch_millis"
    }
  ],
  "sort" : [
    {
      "bytes" : {
        "order" : "desc",
        "missing" : "_first",
        "unmapped_type" : "long"
      }
    }
  ]
}
```

---
```
POST /_sql/translate
{
  "query": "SELECT * FROM kibana_sample_data_logs where request='342342' or agent!='msewef'",
  "fetch_size": 10
}
```
```json
{
  "size" : 10,
  "query" : {
    "bool" : {
      "should" : [
        {
          "term" : {
            "request.keyword" : {
              "value" : "342342",
              "boost" : 1.0
            }
          }
        },
        {
          "bool" : {
            "must_not" : [
              {
                "term" : {
                  "agent.keyword" : {
                    "value" : "msewef",
                    "boost" : 1.0
                  }
                }
              }
            ],
            "adjust_pure_negative" : true,
            "boost" : 1.0
          }
        }
      ],
      "adjust_pure_negative" : true,
      "boost" : 1.0
    }
  },
  "_source" : {
    "includes" : [
      "agent",
      "bytes",
      "clientip",
      "extension",
      "host",
      "index",
      "ip",
      "machine.os",
      "machine.ram",
      "memory",
      "message",
      "phpmemory",
      "request",
      "response",
      "tags",
      "url"
    ],
    "excludes" : [ ]
  },
  "docvalue_fields" : [
    {
      "field" : "@timestamp",
      "format" : "epoch_millis"
    },
    {
      "field" : "event.dataset"
    },
    {
      "field" : "geo.coordinates"
    },
    {
      "field" : "geo.dest"
    },
    {
      "field" : "geo.src"
    },
    {
      "field" : "geo.srcdest"
    },
    {
      "field" : "referer"
    },
    {
      "field" : "timestamp",
      "format" : "epoch_millis"
    },
    {
      "field" : "utc_time",
      "format" : "epoch_millis"
    }
  ],
  "sort" : [
    {
      "_doc" : {
        "order" : "asc"
      }
    }
  ]
}

```