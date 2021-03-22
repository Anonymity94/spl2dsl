# Splunk-SPL-to-ElasticSearch-DSL

基于 `Splunk` 的 `SPL` 查询语言转换成 `ElasticSearch` 的 `DSL`。

~~转换结果和 [SQL access » SQL Translate API](https://www.elastic.co/guide/en/elasticsearch/reference/7.8/sql-translate.html) 对齐。~~

可以配置 [Wrapper query](https://www.elastic.co/guide/en/elasticsearch/reference/7.10/query-dsl-wrapper-query.html) 进行表达式搜索。

## Usage

```js
const converter = require("./lib/converter")

try {
  const { target, dev } = converter.parse(`| search a=1 and b=2`);
  // 完整的es搜索语句
  console.log(target)
  // 一些查询字段值，目前只存放了时间范围
  // 以后可以在基础上拓展，返回所有的查询字段，方便自定义校验字段名和字段值
  console.log(dev)
} catch (error) {
  console.log(error.message);
}

```

```html
<script src="../lib/converter.min.js"></script>

<script>
  try {
    var result = splToDslConverter.parse(value, {
      json: true,
    });
  } catch (error) {
    console.log(error);
  }
</script>
```



## 开发

```sh
yarn

# build
yarn build

# test
yarn test
```

## 一个完整的搜索

```
# `ip_initiator` 为 `'10.0.0.1'`
# 并且 `ip_protocol` 的值为 `TCP` 或 `UDP`
# 并且 `port_initiator` 大于 `80`
# 并且 `port_initiator` 小于 `100`
# 并且 `start_time` 的值在7天前到现在之间
# 以 `start_time` 倒序排序
# 返回30条数据

ip_initiator = '10.0.0.1' AND ip_protocol in ('TCP', 'UDP') AND port_initiator > 80 AND port_initiator < 100
| gentimes start_time start=now-7d end=now
| sort -start_time
| head 30
```

## 语法说明

```
# 搜索表名，可以省略
[source <tableName>]
# 搜索字段
[[| search] <field-name> <operate> <field-value>] [<logical-connector> <field-name> <operate> <field-value>]]

# 限制时间
[| gentimes <time-field> start <time-value> [end <time-value>]]

# 排序,+为正序，-为倒序
[| sort <sort-operate> <sort-field> [, <sort-operate> <sort-field>]]

# 返回前多少条
[| head <int>]

```



## 参数说明

|         参数          |    名称    | 描述                                                         |
| :-------------------: | :--------: | ------------------------------------------------------------ |
|    `<field-name>`     |   字段名   | 允许输入大小字母、数字、下划线[`_`]、英文的点[`.`]<br />例如：`start_time`、`cup.usage` |
|      `<operate>`      |   操作符   | `=`、`!=`、`>`、`>=`、`<`、`<=`                              |
|    `<field-value>`    |   字段值   | 允许输入大小字母、数字、下划线[`_`]、英文的点[`.`]、冒号[`:`]、正斜杠[`/`]、通配符[`*`]、通配符[`?`]。<br />允许内容被单引号[`''`]或双引号[`""`]包裹。含有通配符时，将会使用ES中的[Wildcard query](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-wildcard-query.html)<br />例如：`12`、`"1.2"`、`"中国"`、`"a_b"` |
| `<logical-connector>` | 逻辑关系符 | `and`、`AND`、`or`、`OR`、`&&`、`||`                         |
|    `<time-field>`     | 时间字段名 | 同`<field-name>`                                             |
|    `<time-value>`     | 时间内容值 | [时间范围](#时间范围)                                        |
|    `<sort-field>`     | 排序字段名 | 同`<field-name>`                                             |
|   `<sort-operate>`    |  排序符号  | `+` 正序<br />`-` 倒序                                       |


## Demo

### 时间条件

```
| gentimes start_time start=2020-07-13T00:00:00+08 end=2020-07-13T23:59:59+08

// end时间可以省略，下面2个查询条件是等价的
| gentimes start_time start=now-2d
| gentimes start_time start=now-2d end=now

| gentimes start_time start=1594569600000 end=1594624363506
```

### 字段条件

⚠️ 开头的 `| search` 可省略

#### 查询一个字段

```
| search a=1
等价于
 a=1
```

#### 使用逻辑关系表达式查询多个字段

```
 | search a=1 and b>4
 a=1 && (b=1 AND (c="2" OR c='3')) OR d!='2'
 | search a=1 and b in ('2','3','4')
 | search a=1 or b in ('2','3','4')
```

#### 模糊查询

⚠️ 为了保证搜索性能，请避免使用 * 或开头模式 ?

支持两个通配符运算符： 

- `?`，它与任何单个字符匹配
- `*`，可以匹配零个或多个字符，包括一个空字符



例1，匹配 `kiy`、` kity` 或  `kimchy`

```
| search a="ki*y"
```



例2，匹配 `C1K0-KD345`、` C2K5-DFG65`、 `C4K8-UI365`

```
# 搜索以C开头，第一个字符必须为C，第二字符随意，第三个字符必须是K
| search a="C?K*"
```

#### 查询范围

```
| search a>1 and a<10
| search a>1 and a<=10
| search a>=1 and a<=10
```



#### 字段命中多个值

```| search a in (2,5,6)
等价于
| search a=2 and a=5 and a=6
```

#### 字段排除多个值

```
| search a NOT IN (2,5,6)
等价于
| search a!=2 and a!=5 and a!=6
```

#### 操作符 `EXISTS`

> [query-dsl-exists-query](https://www.elastic.co/guide/en/elasticsearch/reference/7.9/query-dsl-exists-query.html)
> Returns documents that contain an indexed value for a field.\n
> An indexed value may not exist for a document’s field due to a variety of reasons:
> - The field in the source JSON is null or []
> - The field has "index" : false set in the mapping
> - The length of the field value exceeded an ignore_above setting in the mapping
> - The field value was malformed and ignore_malformed was defined in the mapping

`ES` 中只会排除 `NULL` 或 `[]`这 2 类值，我给做出了拓展，新增了空字符串 `''`，这 3 类值以外的其他的都会被命中。

```json
# name 字段不为空
name EXISTS
```

#### 操作符 `NOT_EXISTS`

搜索不存在值的字段，字段值为 `''` 或 `NULL` 或 `[]` 时会被命中。

```json
# name 不存在值
name NOT_EXISTS
```

### 限制返回条数

```
# 返回前100条数据
| head 100
```

###  排序

```
# create_time倒序，state正序
| sort -create_time, +state
```



## 时间范围

针对时间格式做处理一些调整，这里的时间格式和`Splunk`中标准的时间格式不同。

#### splunk标准格式

`Splunk` 中的时间格式为：`| gentimes start=<timestamp> [end=<timestamp>] [increment=<increment>]` [Gentimes文档](https://docs.splunk.com/Documentation/Splunk/8.0.5/SearchReference/Gentimes)

其中 `timestamp` 的格式为：`MM/DD/YYYY[:HH:MM:SS] | <int>`



---

#### 修改后的时间内容值

`| gentimes <time-field> start=<time-value> [end=<time-value>]`

时间的内容值可以分为**相对时间**和**绝对时间**：

- 相对时间

  - `now` 当前时间

  - `now-<int>(y | M | w | d | H | h | m | s)`

    | 单位       | 说明      |
    | ---------- | --------- |
    | `y`        | `Year`    |
    | `M`        | `Months`  |
    | `w`        | `Weeks`   |
    | `d`        | `Days`    |
    | `h` or `H` | `Hours`   |
    | `m`        | `Minutes` |
    | `s`        | `Seconds` |

    例如：`now-7d`，7天前

- 绝对时间

  - `2017-04-01T12:34:56+08`
  - `2017-04-01T12:34:56+0800`
  - `2017-04-01T12:34:56+08:00`
  - 时间戳（毫秒）

#### 使用Demo

- `| gentimes time-field start=2020-07-13T00:00:00+08 end=2020-07-13T23:59:59+08`
- `| gentimes start=now-7d end=now`
- `| gentimes start=1594569600000 end=1594624363506`



## Links

- [Splunk Search Reference](https://docs.splunk.com/Documentation/Splunk/8.0.4/SearchReference/Abstract)
- [Elasticsearch Query DSL](https://www.elastic.co/guide/en/elasticsearch/reference/7.8/query-dsl.html)
- [查询Elasticsearch中的数据 (基于DSL的查询, 包括validate、match、bool)](https://www.cnblogs.com/shoufeng/p/11096521.html)
- [SQL access » SQL Translate API](https://www.elastic.co/guide/en/elasticsearch/reference/7.8/sql-translate.html)
- [PEG.js Online Version](https://pegjs.org/online)


## FAQ

### 🤔`terms` or `match`?

- [Term Query](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-term-query.html)精确查询，对查询的值不分词,直接进倒排索引去匹配。
- [Match Query](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-match-query.html) ：模糊查询，对查询的值分词，对分词的结果一一进入倒排索引去匹配



### 🤔 `GET` 查询中加不加`.keyword`?

--

### 🤔 `filter` 和 `query` 查询的不同?

[Elasticsearch DSL中Query与Filter的区别](https://blog.csdn.net/xifeijian/article/details/50823110)
[Elasticsearch filter和query的不同](https://blog.csdn.net/wojiushiwo987/article/details/80468757)

### 🤔 前缀匹配查询？通配符查询？

[Prefix Query](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-prefix-query.html)
[Wildcard query](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-wildcard-query.html)


## 参考
- [Wrapper query](https://www.elastic.co/guide/en/elasticsearch/reference/7.10/query-dsl-wrapper-query.html)