#!/usr/bin/env node
const converter = require("../index");

describe("Splunk SPL to ElasticSearch DSL test", () => {
  const spl1 = " | search age=30";
  test(spl1, () => {
    const dsl1 = converter.parse(spl1, { json: true });
    expect(dsl1).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  term: {
                    age: {
                      value: "30",
                      boost: 1,
                    },
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["age"],
        },
      },
    });
  });

  const spl2 = " a=1 && (b=1 AND (c='2' OR c='3')) OR d!='2'";
  test(spl2, () => {
    const dsl2 = converter.parse(spl2, { json: true });
    expect(dsl2).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  bool: {
                    should: [
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                a: {
                                  value: "1",
                                  boost: 1,
                                },
                              },
                            },
                            {
                              bool: {
                                must: [
                                  {
                                    term: {
                                      b: {
                                        value: "1",
                                        boost: 1,
                                      },
                                    },
                                  },
                                  {
                                    bool: {
                                      should: [
                                        {
                                          term: {
                                            c: {
                                              value: "2",
                                              boost: 1,
                                            },
                                          },
                                        },
                                        {
                                          term: {
                                            c: {
                                              value: "3",
                                              boost: 1,
                                            },
                                          },
                                        },
                                      ],
                                      adjust_pure_negative: true,
                                      boost: 1,
                                    },
                                  },
                                ],
                                adjust_pure_negative: true,
                                boost: 1,
                              },
                            },
                          ],
                          adjust_pure_negative: true,
                          boost: 1,
                        },
                      },
                      {
                        bool: {
                          must_not: [
                            {
                              term: {
                                d: {
                                  value: "2",
                                  boost: 1,
                                },
                              },
                            },
                          ],
                        },
                      },
                    ],
                    adjust_pure_negative: true,
                    boost: 1,
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["a", "b", "c", "d"],
        },
      },
    });
  });

  const spl3 = " a>=1 && b<2 && c<=3 || d > 4";
  test(spl3, () => {
    const dsl3 = converter.parse(spl3, { json: true });
    expect(dsl3).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  bool: {
                    should: [
                      {
                        bool: {
                          must: [
                            {
                              range: {
                                a: {
                                  gte: "1",
                                },
                              },
                            },
                            {
                              bool: {
                                must: [
                                  {
                                    range: {
                                      b: {
                                        lt: "2",
                                      },
                                    },
                                  },
                                  {
                                    range: {
                                      c: {
                                        lte: "3",
                                      },
                                    },
                                  },
                                ],
                                adjust_pure_negative: true,
                                boost: 1,
                              },
                            },
                          ],
                          adjust_pure_negative: true,
                          boost: 1,
                        },
                      },
                      {
                        range: {
                          d: {
                            gt: "4",
                          },
                        },
                      },
                    ],
                    adjust_pure_negative: true,
                    boost: 1,
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["a", "b", "c", "d"],
        },
      },
    });
  });

  const spl4 =
    " | GENTIMES start_time start=2020-07-13T00:00:00+08 end=2020-07-13T23:59:59+08";
  test(spl4, () => {
    const dsl4 = converter.parse(spl4, { json: true });
    expect(dsl4).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  bool: {
                    must: {
                      range: {
                        start_time: {
                          from: "2020-07-13T00:00:00+08",
                          to: "2020-07-13T23:59:59+08",
                          include_lower: true,
                          include_upper: true,
                        },
                      },
                    },
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {
            time_field: "start_time",
            time_from: "2020-07-13T00:00:00+08",
            time_to: "2020-07-13T23:59:59+08",
          },
          fields: ["start_time"],
        },
      },
    });
  });

  const spl5 = " | gentimes start_time start=now-2d end=now";
  test(spl5, () => {
    const dsl5 = converter.parse(spl5, { json: true });
    expect(dsl5).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  bool: {
                    must: {
                      range: {
                        start_time: {
                          from: "now-2d",
                          to: "now",
                          include_lower: true,
                          include_upper: true,
                        },
                      },
                    },
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {
            time_field: "start_time",
            time_from: "now-2d",
            time_to: "now",
          },
          fields: ["start_time"],
        },
      },
    });
  });

  const spl6 =
    " | gentimes start_time start=1594569600000 end=1594624363506";
  test(spl6, () => {
    const dsl6 = converter.parse(spl6, { json: true });
    expect(dsl6).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  bool: {
                    must: {
                      range: {
                        start_time: {
                          from: 1594569600000,
                          to: 1594624363506,
                          include_lower: true,
                          include_upper: true,
                        },
                      },
                    },
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {
            time_field: "start_time",
            time_from: 1594569600000,
            time_to: 1594624363506,
          },
          fields: ["start_time"],
        },
      },
    });
  });

  const spl7 = " | head 100";
  test(spl7, () => {
    const dsl7 = converter.parse(spl7, { json: true });
    expect(dsl7).toStrictEqual({
      result: {
        target: {
          query: {
            match_all: {},
          },
          from: 0,
          size: 100,
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: [],
        },
      },
    });
  });

  const spl8 = " | search a=腾讯 and b in (2, 3)";
  test(spl8, () => {
    const dsl8 = converter.parse(spl8, { json: true });
    expect(dsl8).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  bool: {
                    must: [
                      {
                        term: {
                          a: {
                            value: "腾讯",
                            boost: 1,
                          },
                        },
                      },
                      {
                        terms: {
                          b: ["2", "3"],
                          boost: 1,
                        },
                      },
                    ],
                    adjust_pure_negative: true,
                    boost: 1,
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["a", "b"],
        },
      },
    });
  });

  const spl9 = " | search a='ki*y'";
  test(spl9, () => {
    const dsl9 = converter.parse(spl9, { json: true });
    expect(dsl9).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  wildcard: {
                    a: {
                      value: "ki*y",
                    },
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["a"],
        },
      },
    });
  });

  const spl10 = " | search a='C?K*'";
  test(spl10, () => {
    const dsl10 = converter.parse(spl10, { json: true });
    expect(dsl10).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  wildcard: {
                    a: {
                      value: "C?K*",
                    },
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["a"],
        },
      },
    });
  });

  const spl11 =
    " | search a='C?K*' and a=1 && (b=1 AND (c='2' OR c='3')) OR d!='2' | gentimes start_time start=1594569600000 end=1594624363506 | head 100";
  test(spl11, () => {
    const dsl11 = converter.parse(spl11, { json: true });
    expect(dsl11).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  bool: {
                    must: [
                      {
                        bool: {
                          should: [
                            {
                              bool: {
                                must: [
                                  {
                                    wildcard: {
                                      a: {
                                        value: "C?K*",
                                      },
                                    },
                                  },
                                  {
                                    bool: {
                                      must: [
                                        {
                                          term: {
                                            a: {
                                              value: "1",
                                              boost: 1,
                                            },
                                          },
                                        },
                                        {
                                          bool: {
                                            must: [
                                              {
                                                term: {
                                                  b: {
                                                    value: "1",
                                                    boost: 1,
                                                  },
                                                },
                                              },
                                              {
                                                bool: {
                                                  should: [
                                                    {
                                                      term: {
                                                        c: {
                                                          value: "2",
                                                          boost: 1,
                                                        },
                                                      },
                                                    },
                                                    {
                                                      term: {
                                                        c: {
                                                          value: "3",
                                                          boost: 1,
                                                        },
                                                      },
                                                    },
                                                  ],
                                                  adjust_pure_negative: true,
                                                  boost: 1,
                                                },
                                              },
                                            ],
                                            adjust_pure_negative: true,
                                            boost: 1,
                                          },
                                        },
                                      ],
                                      adjust_pure_negative: true,
                                      boost: 1,
                                    },
                                  },
                                ],
                                adjust_pure_negative: true,
                                boost: 1,
                              },
                            },
                            {
                              bool: {
                                must_not: [
                                  {
                                    term: {
                                      d: {
                                        value: "2",
                                        boost: 1,
                                      },
                                    },
                                  },
                                ],
                              },
                            },
                          ],
                          adjust_pure_negative: true,
                          boost: 1,
                        },
                      },
                      {
                        bool: {
                          must: {
                            range: {
                              start_time: {
                                from: 1594569600000,
                                to: 1594624363506,
                                include_lower: true,
                                include_upper: true,
                              },
                            },
                          },
                        },
                      },
                    ],
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          from: 0,
          size: 100,
          track_total_hits: true,
        },
        dev: {
          time_range: {
            time_field: "start_time",
            time_from: 1594569600000,
            time_to: 1594624363506,
          },
          fields: ["a", "b", "c", "d", "start_time"],
        },
      },
    });
  });

  const spl12 = " | search ip='ff02::1:ff8e:9176'";
  test(spl12, () => {
    const dsl12 = converter.parse(spl12, { json: true });
    expect(dsl12).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  term: {
                    ip: {
                      value: "ff02::1:ff8e:9176",
                      boost: 1,
                    },
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["ip"],
        },
      },
    });
  });

  const spl13 = " | search a='/publish'";
  test(spl13, () => {
    const dsl13 = converter.parse(spl13, { json: true });
    expect(dsl13).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  term: {
                    a: {
                      value: "/publish",
                      boost: 1,
                    },
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["a"],
        },
      },
    });
  });

  const spl14 = " | search a NOT IN (1,2,3,4)";
  test(spl14, () => {
    const dsl14 = converter.parse(spl14, { json: true });
    expect(dsl14).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  bool: {
                    must_not: [
                      {
                        terms: {
                          a: ["1", "2", "3", "4"],
                          boost: 1,
                        },
                      },
                    ],
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["a"],
        },
      },
    });
  });

  const spl15 = " | search a='腾 讯' and b !='阿 里 巴 巴'";
  test(spl15, () => {
    const dsl15 = converter.parse(spl15, { json: true });
    expect(dsl15).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  bool: {
                    must: [
                      {
                        term: {
                          a: {
                            value: "腾 讯",
                            boost: 1,
                          },
                        },
                      },
                      {
                        bool: {
                          must_not: [
                            {
                              term: {
                                b: {
                                  value: "阿 里 巴 巴",
                                  boost: 1,
                                },
                              },
                            },
                          ],
                        },
                      },
                    ],
                    adjust_pure_negative: true,
                    boost: 1,
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["a", "b"],
        },
      },
    });
  });

  const spl16 = " | search a like 'aaa'";
  test(spl16, () => {
    const dsl16 = converter.parse(spl16, { json: true });
    expect(dsl16).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  wildcard: {
                    a: {
                      value: "aaa",
                    },
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["a"],
        },
      },
    });
  });

  const spl17 = "a exists";
  test(spl17, () => {
    const dsl17 = converter.parse(spl17, { json: true });
    expect(dsl17).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  bool: {
                    must: [
                      {
                        exists: {
                          field: "a",
                        },
                      },
                      {
                        bool: {
                          must_not: [
                            {
                              term: {
                                "a.keyword": {
                                  value: "",
                                  boost: 1,
                                },
                              },
                            },
                            {
                              term: {
                                "a.keyword": {
                                  value: "-",
                                  boost: 1,
                                },
                              },
                            },
                          ],
                        },
                      },
                    ],
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["a"],
        },
      },
    });
  });

  const spl18 = "a not_exists";
  test(spl18, () => {
    const dsl18 = converter.parse(spl18, { json: true });
    expect(dsl18).toStrictEqual({
      result: {
        target: {
          query: {
            bool: {
              filter: [
                {
                  bool: {
                    should: [
                      {
                        bool: {
                          must_not: [
                            {
                              exists: {
                                field: "a",
                              },
                            },
                          ],
                        },
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                "a.keyword": {
                                  value: "",
                                  boost: 1,
                                },
                              },
                            },
                          ],
                        },
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                "a.keyword": {
                                  value: "-",
                                  boost: 1,
                                },
                              },
                            },
                          ],
                        },
                      },
                    ],
                  },
                },
              ],
              adjust_pure_negative: true,
              boost: 1,
            },
          },
          track_total_hits: true,
        },
        dev: {
          time_range: {},
          fields: ["a"],
        },
      },
    });
  });
});
