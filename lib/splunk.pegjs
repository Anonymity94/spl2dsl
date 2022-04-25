{
  var EQUAL = '=';
  var NOT_EQUAL = '!=';

  var AND = 'AND';
  var OR = 'OR';

  var PLUS = '+';
  
  var fields = [];

  // 结果是否需要变成json
  const { json = false } = options;

  /**
  * 数组去重
  */
  function uniqueArray(array) {
    // return arr.reduce(
    //   (prev, cur) => (prev.includes(cur) ? prev : [...prev, cur]),
    //   []
    // );
    // java调用，无法使用ES6语法
    return array.filter((item,index,array)=>{
      return array.indexOf(item) === index 
    })
  }

  /**
  * 转换逻辑表达式
  */
  function logicalExpressionTransform(region = {}) {
    var { left, connector, right } = region;
    let esConnector = "";
    if (connector === AND) {
      esConnector = "must";
    }
    if (connector === OR) {
      esConnector = "should";
    }
    if (esConnector) {
      return {
        bool: {
          [esConnector]: [
            logicalExpressionTransform(left),
            logicalExpressionTransform(right)
          ],
          adjust_pure_negative: true,
          boost: 1.0
        }
      };
    }
    return region;
  }

  /**
  * 判断对象是否为空
  */
  function objectIsEmpty(obj) {
    if (!obj) return true;
    if (Object.keys(obj).length === 0) return true;

    return false;
  }

  /**
  * 组合查询条件语句
  * @param {Object} searchDsl 字段的搜索条件
  * @param {Object} timeQuery 时间搜索条件
  */
  function renderFullDsl(searchDsl, timeQuery) {
    var isFieldQueryEmpty = objectIsEmpty(searchDsl);
    var isTimeQueryEmpty = objectIsEmpty(timeQuery);

    if (isFieldQueryEmpty && isTimeQueryEmpty) {
      return { query: { match_all: {} } };
    }

    if (!isFieldQueryEmpty && isTimeQueryEmpty) {
      return {
        query: {
          bool: {
            filter: [searchDsl],
            adjust_pure_negative: true,
            boost: 1.0
          }
        }
      };
    }

    if (isFieldQueryEmpty && !isTimeQueryEmpty) {
      return {
        query: {
          bool: {
            filter: [timeQuery],
            adjust_pure_negative: true,
            boost: 1.0
          }
        }
      };
    }

    return {
      query: {
        bool: {
          filter: [{
            bool: {
              must: [searchDsl, timeQuery]
            }
          }],
          adjust_pure_negative: true,
          boost: 1.0
        }
      }
    };
  }
}

start
  = DslExpression

DslExpression "DslExpression"
  = searchDsl:SourceAndSearchExpression tail:(_? divider _? TailCommand)* __? {
    var tailMap = {}
    // 处理时间查询条件
    var timeDsl = {};
    var timeRange = {};
    tail.forEach(item => {
    	if(item && item[3]) {
        if(item[3].hasOwnProperty('gentimes')) {
          timeRange = item[3].gentimes;
          timeDsl = {
            bool: {
              must: {
                range: {
                  [timeRange.time_field]: {
                    from: timeRange.time_from,
                    to: timeRange.time_to,
                    include_lower: true, // 包含开始时间
                    include_upper: true, // 包含结束时间
                  }
                }
              }
            }
          }
        } else {
          tailMap = Object.assign(tailMap, item[3])
        }
      }
    })

    // 处理下时间范围，拼接到字段搜索条件里面
    var fullDsl = renderFullDsl(searchDsl, timeDsl);
    // 增加dev参数，添加一些方便外层拿到参数，比如时间，后续如果想做校验字段是否存在，可以在此基础上修改
    const result = {
      target: Object.assign({}, fullDsl, tailMap, {track_total_hits: true} ),
      dev: {
       	time_range: {...timeRange},
        fields: fields
      }
    }

    return {
      result: json ? result : JSON.stringify(result)
    }
  }

// ----- 查询条件 -----
SourceAndSearchExpression "SourceAndSearchExpression"
  = sourceArr:(SOURCE __ equal __ source:DataSource)? searchArr:(__ SearchExpression)? {
  	if(!searchArr || !searchArr[1] || searchArr.length === 0) {
    	return {}
    }
    return searchArr[1];
  }

SearchExpression "SearchExpression"
  = (divider __ SEARCH _)? region:RegionOr {
    return logicalExpressionTransform(region)
  }

RegionOr "RegionOr"
  = left:RegionAnd Whitespace+ OrExpression Whitespace+ right:RegionOr { return {connector: "OR", left:left, right:right} }
  / RegionAnd

RegionAnd "RegionAnd"
  = left:FactorBlock Whitespace+ AndExpression Whitespace+ right:RegionAnd { return {connector: "AND", left:left, right:right} }
  / FactorBlock

FactorBlock "FactorBlock"
//  = WildcardCondition
 = BasicCondition
 / parenStart Whitespace* RegionOr:RegionOr Whitespace* parenEnd { return RegionOr; }

// 基本的等式
BasicCondition "BasicCondition"
  = field:Field __ op:(equal / notEqual / gte / gt / lte / lt) __ value:Value {
    // 如果操作符不是等于，并且存在 * 或者是 ?, 抛异常
    if(op !== '=' && (value.indexOf('*') > -1 || value.indexOf('?') > -1)) {
      throw Error('模糊查询时只能使用等于[=]。例如：name="abcd?e"')
    }
    if(op === '=') {
      // 存在 * 或者是 ? 时，走模糊查询
      if(value.indexOf('*') > -1 || value.indexOf('?') > -1) {
        if(value.charAt(0) === '?' || (value.length === 1 && value === '*')) {
          throw Error('避免使用*或开头模式?。这会增加查找匹配项所需的迭代次数，并降低搜索性能。')
          // throw Error('Avoid beginning patterns with * or ?. This can increase the iterations needed to find matching terms and slow search performance.')
        }
        return {
          "wildcard": {
            [field]: {
              "value": value
            }
          }
        }
      }
      return {
        term: {
          [`${field}`]: {
            value: value,
            boost: 1.0
          }
        }
      }
    }
    if(op === '!=') {
      return {
        bool: {
          must_not: [{
            term: {
              [`${field}`]: {
                value: value,
                boost: 1.0
              }
            }
          }]
        }
      }
    }

    var opText = '';
    if(op === '>') {opText = 'gt'}
    if(op === '>=') {opText = 'gte'}
    if(op === '<') {opText = 'lt'}
    if(op === '<=') {opText = 'lte'}
    if(opText) {
      return {
        range: {
          [field]: {
            [opText]: value
          }
        }
      }
    }

    return {}
  }
  / LikeCondition
  / InCondition
  / NotInCondition
  / ExistsCondition
  / NotExistsCondition

LikeCondition "LikeCondition"
  = field:Field _ LIKE _ value:Value {
    return {
      "wildcard": {
        [field]: {
          "value": value
        }
      }
    }
  }

InCondition "InCondition"
  = field:Field _ IN _ parenStart __ values:MultipleValue __ parenEnd {
    return {
      terms: {
        [`${field}`]: values,
        boost: 1.0
      }
    }
  }
  
NotInCondition "NotInCondition"
  = field:Field _ NOT_IN _ parenStart __ values:MultipleValue __ parenEnd {
    return {
      bool: {
        must_not: [{
          terms: {
            [`${field}`]: values,
            boost: 1.0
          }
        }]
      }
    }
  }

// @see: https://www.elastic.co/guide/en/elasticsearch/reference/7.9/query-dsl-exists-query.html
ExistsCondition "ExistsCondition"
  = field:Field _ EXISTS {
    return {
      bool: {
        must: [
          {
            exists: {
              field: field,
            },
          },
          {
            bool: {
              must_not: [
                {
                  term: {
                    [`${field}.keyword`]: {
                      value: "",
                      boost: 1,
                    },
                  },
                },
                {
                  term: {
                    [`${field}.keyword`]: {
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
    }
  }

NotExistsCondition "NotExistsCondition"
  = field:Field _ NOT_EXISTS {
    return {
      bool: {
        should: [
          {
            bool: {
              must_not: [
                {
                  exists: {
                    field: field,
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
                    [`${field}.keyword`]: {
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
                    [`${field}.keyword`]: {
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
    };
  }


MultipleValue "MultipleValue"
  = first:Value rest:MoreMultipleValues* {
    var result = [first].concat(rest);
 	  // 数组去重一下
    return uniqueArray(result)
  }

MoreMultipleValues "MoreMultipleValues"
	= __ ',' __ value:Value { return value }

// 通配符表达式
WildcardCondition
  = field:Field __ equal __ value:WildcardValue {
    if(value.charAt(0) === '?' || (value.length === 1 && value === '*')) {
      throw Error('避免使用*或开头模式?。这会增加查找匹配项所需的迭代次数，并降低搜索性能。')
      // throw Error('Avoid beginning patterns with * or ?. This can increase the iterations needed to find matching terms and slow search performance.')
    }
  	return {
    	"wildcard": {
      	[field]: {
          "value": value
      	}
  		}
  	}
  }

WildcardValue
	= $[a-zA-Z0-9\._\-\*?]+
  / '"' char:WildcardValue '"' {
    return char
  }
  / "'" char:WildcardValue "'" {
    return char
  }

// ----- search后面的其他命令 -----
TailCommand "TailCommand"
  = FieldsCommand
  / HeadCommand
  / SortCommand
  / GentimesCommand

  // ES的查询参数
  // / SizeCommand
  // / TimeoutCommand
  // / TrackTotalCommand
  // / TerminateAfterCommand

// ----- 查询结果中包含（排除）的字段 -----
// @see: https://docs.splunk.com/Documentation/Splunk/8.0.4/SearchReference/Fields
FieldsCommand "FieldsCommand"
  = __ FIELDS _ first:SourceField rest:MoreSourceFields* {
    var fieldsArr = [first].concat(rest)
    // +的放在includes，-放在excludes
    var includes = [];
    var excludes = [];
    fieldsArr.forEach(({op, field}) => {
      if(op === '+') {includes.push(field)}
      if(op === '-') {excludes.push(field)}
    })
 	  return {_source: {includes, excludes}}
  }

SourceField "SourceField"
  = _? op:(plus / minus)? _? field:Field { return {op: op || '+', field} }

MoreSourceFields 'MoreSourceFields'
  = __ ',' __ field:SourceField { return field }

// ----- Top -----
TopCommand "TopCommand"
  = __ TOP _ 'limit=' __ number:Integer _ field:Field {
    // TODO:
    return {}
  }

// ----- head -----
// @see: https://docs.splunk.com/Documentation/Splunk/8.0.4/SearchReference/Head
HeadCommand "HeadCommand"
  = __ HEAD _ number:Integer {
    if(number <=0) {
      throw Error('返回结果的数量至少为1');
    }
  	// 是否需要限制最大查询上限为1w？
 	  return {
      from: 0,
      size: number
    }
  }

// ----- sort 排序 -----
// @see: https://docs.splunk.com/Documentation/Splunk/8.0.4/SearchReference/Sort
SortCommand "SortCommand"
  = __ SORT _ op:(plus / minus)? first:Field rest:MoreSort* {
 	  // +ip/ip ==> {ip: {order: 'asc'}}
    // -ip ==> {ip: {order: 'desc'}}
    var sortsArr = [[op, first]].concat(rest);
    // [[操作符, 字段], [操作符, 字段]]
    var sortDsl = {}
    if(sortsArr.length > 0) {
      var r = [];
      sortsArr.forEach(([op, field]) => {
        r.push({[field]: {order: (!op || op === PLUS) ? 'asc': 'desc'}})
      })

      sortDsl.sort = r;
    }
    return sortDsl
  }

MoreSort "MoreSort"
  = __ ',' __ op:(plus / minus)? field:Field { return [op, field] }

// ----- 时间范围 -----
// 不支持未来的时间
// @see: https://docs.splunk.com/Documentation/Splunk/8.0.4/SearchReference/Gentimes
GentimesCommand "GentimesCommand"
  // 开始时间 / 截至时间
  = __ GENTIMES _ field:Field _ 'start'i __ equal __ startTime:TimeValue endTimeArr:(_ 'end'i __ equal __ TimeValue __)* {
    var endTime = 'now';
    if(endTimeArr.length > 0) {
    	endTime = endTimeArr[0][5]
    }
    
    return {
      gentimes: {
        time_field: field,
        time_from: startTime,
        time_to: endTime
      }
    }
  }

TimeValue "TimeValue"
  = RelativeTime
  / UTCTime
  / Timestamp
  / TimeNow
  / '"' char:TimeValue '"' {
    return char
  }
  / "'" char:TimeValue "'" {
    return char
  }

// 相对时间
// @see: https://www.elastic.co/guide/en/elasticsearch/reference/7.8/common-options.html#date-math
// @eg. -10m #1分钟前
// @eg. -1d #1天前
// @eg. -1M #1个月前
// y - Year
// M - Months
// w - Weeks
// d - Days
// h - Hours
// H - Hours
// m - Minutes
// s - Seconds
RelativeTime "RelativeTime"
  = 'now-' number:Integer timeUnit:TimeUnit {
    return text()
  }

// 当前时间
TimeNow "now" = 'now' { return text() }
// 时间单位
TimeUnit "TimeUnit" = ('y' / 'M' / 'w' / 'd' / 'h' / 'H' / 'm' / 's') {return text()}

// 绝对时间
AbsoluteTime "AbsoluteTime"
  = Timestamp
  / UTCTime

// 毫秒时间戳
Timestamp "Timestamp" = timestamp:Integer {
  if(String(timestamp).length !== 13) {
    throw Error('请输入毫秒级的时间戳')
    // throw Error('Please enter a timestamp in milliseconds')
  }
  return timestamp
}

// UTC时间
UTCTime "UTCTime"
  // @eg. 2017-04-01T12:34:56+08
  // @eg. 2017-04-01T12:34:56+0800
  // @eg. 2017-04-01T12:34:56+08:00
  = year:Integer '-' month:Integer '-' day:Integer 'T' hours:Integer ':' minutes:Integer ':' seconds:Integer timeZone:TimeZone {
    if(timeZone) {
      var [op, timeZoneString, suffix] = timeZone;
      // 判断时区范围
      var timeZoneNumber = parseInt(timeZoneString);
      if(timeZoneNumber > 12 || timeZoneNumber < -12) {
        throw Error('错误的时区范围')
        // throw Error('Wrong time zone range')
      }
      if(
      	(suffix && suffix.length < 2)
        || (suffix && suffix.length === 2 && (suffix[0] !== '0' || suffix[1] !== '0'))
      	|| (timeZoneNumber < 10 && (timeZoneString.charAt(0) !== '0' || (timeZoneString.charAt(0) === '0' && timeZoneString.length !== 2)))) {
          throw Error(`时区格式错误. 未能解析日期字段 [${text()}], 请输入 [${op}0${timeZoneNumber}] 或 [${op}0${timeZoneNumber}:00]`)
          // throw Error(`Bad time zone format. failed to parse date field [${text()}], please enter [${op}0${timeZoneNumber}] or [${op}0${timeZoneNumber}:00]`)
      }
      
      return text()
    } else {
    	// 拼接时区信息
    	return `${text()}+08:00`
    }
  }

TimeZone "TimeZone" = op:('+' / '-') numberArr:(num:[0-9]+) suffix:('00' / ':00')? {
  var numberstring = numberArr.join('')
  suffix = suffix || numberstring.slice(2, 4);

	return [op, numberstring.slice(0, 2), suffix]
}

// 返回的文档数量
SizeCommand "SizeCommand"
  = __ SIZE _ number:Integer {
 	  return {
      size: number
    }
  }

// es超时时间设置
TimeoutCommand "TimeoutCommand"
  = __ TIMEOUT _ time:Integer unit:('s' / 'ms') {
 	  return {
		  timeout: `${time}${unit}`
	  }
  }
 
// 是否显示查询结果的总数
TrackTotalCommand "TrackTotalCommand"
  = __ TRACK_TOTAL_HITS _ bool:Boolean {
 	  return {
      track_total_hits: bool
    }
  }
 
// 每个分片要收集的最大文档数，达到该数量时查询执行将提前终止。
TerminateAfterCommand "TerminateAfterCommand" 
  = __ TERMINATE_AFTER _ number:Integer {
 	  return {
      terminate_after: number
    }
  }

// ----- 空白、换行符 -----
_ = [ \t\r\n]+
__ = [ \t\r\n]*
Whitespace = [ ]

// ----- 数据来源 -----
DataSource "DataSource" = $[a-zA-Z0-9\._\-\*]+

// ----- 字段名称 -----
Field 'Field' 
  = prefix:('@' / '_')? str:[A-Za-z0-9_\.]+ {
    const field = (prefix || '') + str.join('');
    // TODO: 排除命令
    // 这里为什么会识别到命令前缀呢？
    if (
      fields.indexOf(field) === -1 &&
      [
        "fields", "FIELDS",
        "sort",  "SORT",
        "gentimes", "GENTIMES",
        "head", "HEAD",
        "timeout", "TIMEOUT",
        "track_total_hits", "TRACK_TOTAL_HITS",
        "terminate_after", "TERMINATE_AFTER"
      ].indexOf(field) === -1
    ) {
      fields.push(field);
    }
    return field
  }
// ----- 字段值 -----
Value "Value"
  = $[\u4e00-\u9fa5_a-zA-Z0-9\.\-?*:\/<>]+
  / '"' char:QuotedValue '"' {
    return char
  }
  / "'" char:QuotedValue "'" {
    return char
  }

QuotedValue "QuotedValue"
   = $[\u4e00-\u9fa5_a-zA-Z0-9\.\-?*:\/<>= ]+
   / ''
   / ""

Integer = num:[0-9]+ { return parseInt(num.join('')); }

AndExpression
  = 'AND'i
  / '&&' { return AND }

OrExpression
  = "OR"i
  / '||' { return OR }

Boolean
  = 'true' { return true; }
  / 'false' { return false; }

divider = '|'
equal = '='
notEqual = '!='
gte = '>='
gt = '>'
lte = '<='
lt = '<'
plus = '+'
minus = '-'
parenStart = '('
parenEnd = ')'

SOURCE = 'SOURCE'i
SEARCH = 'SEARCH'i
FIELDS = "FIELDS"i
HEAD = 'HEAD'i
SORT = 'SORT'i
GENTIMES = 'GENTIMES'i
SIZE = 'SIZE'i
TIMEOUT = 'TIMEOUT'i
TRACK_TOTAL_HITS = 'TRACK_TOTAL_HITS'i
TERMINATE_AFTER = 'TERMINATE_AFTER'i
TOP = "TOP"i
LIMIT = "LIMIT"i
IN = 'IN'i
NOT_IN = "NOT IN"i
LIKE = 'LIKE'i
EXISTS = 'EXISTS'i
NOT_EXISTS = 'NOT_EXISTS'i
