## Tables
### anki2
cards   col     graves  notes   revlog
### anki21b
cards        config       decks        graves       notetypes    tags       
col          deck_config  fields       notes        revlog       template
## Schema
### anki2
CREATE TABLE col (
    id              integer primary key,
    crt             integer not null,
    mod             integer not null,
    scm             integer not null,
    ver             integer not null,
    dty             integer not null,
    usn             integer not null,
    ls              integer not null,
    conf            text not null,
    models          text not null,
    decks           text not null,
    dconf           text not null,
    tags            text not null
);
CREATE TABLE notes (
    id              integer primary key,   /* 0 */
    guid            text not null,         /* 1 */
    mid             integer not null,      /* 2 */
    mod             integer not null,      /* 3 */
    usn             integer not null,      /* 4 */
    tags            text not null,         /* 5 */
    flds            text not null,         /* 6 */
    sfld            integer not null,      /* 7 */
    csum            integer not null,      /* 8 */
    flags           integer not null,      /* 9 */
    data            text not null          /* 10 */
);
CREATE TABLE cards (
    id              integer primary key,   /* 0 */
    nid             integer not null,      /* 1 */
    did             integer not null,      /* 2 */
    ord             integer not null,      /* 3 */
    mod             integer not null,      /* 4 */
    usn             integer not null,      /* 5 */
    type            integer not null,      /* 6 */
    queue           integer not null,      /* 7 */
    due             integer not null,      /* 8 */
    ivl             integer not null,      /* 9 */
    factor          integer not null,      /* 10 */
    reps            integer not null,      /* 11 */
    lapses          integer not null,      /* 12 */
    left            integer not null,      /* 13 */
    odue            integer not null,      /* 14 */
    odid            integer not null,      /* 15 */
    flags           integer not null,      /* 16 */
    data            text not null          /* 17 */
);
CREATE TABLE revlog (
    id              integer primary key,
    cid             integer not null,
    usn             integer not null,
    ease            integer not null,
    ivl             integer not null,
    lastIvl         integer not null,
    factor          integer not null,
    time            integer not null,
    type            integer not null
);
CREATE TABLE graves (
    usn             integer not null,
    oid             integer not null,
    type            integer not null
);
CREATE INDEX ix_notes_usn on notes (usn);
CREATE INDEX ix_cards_usn on cards (usn);
CREATE INDEX ix_revlog_usn on revlog (usn);
CREATE INDEX ix_cards_nid on cards (nid);
CREATE INDEX ix_cards_sched on cards (did, queue, due);
CREATE INDEX ix_revlog_cid on revlog (cid);
CREATE INDEX ix_notes_csum on notes (csum);
CREATE TABLE sqlite_stat1(tbl,idx,stat);
### anki21b
CREATE TABLE col (
  id integer PRIMARY KEY,
  crt integer NOT NULL,
  mod integer NOT NULL,
  scm integer NOT NULL,
  ver integer NOT NULL,
  dty integer NOT NULL,
  usn integer NOT NULL,
  ls integer NOT NULL,
  conf text NOT NULL,
  models text NOT NULL,
  decks text NOT NULL,
  dconf text NOT NULL,
  tags text NOT NULL
);
CREATE TABLE notes (
  id integer PRIMARY KEY,
  guid text NOT NULL,
  mid integer NOT NULL,
  mod integer NOT NULL,
  usn integer NOT NULL,
  tags text NOT NULL,
  flds text NOT NULL,
  -- The use of type integer for sfld is deliberate, because it means that integer values in this
  -- field will sort numerically.
  sfld integer NOT NULL,
  csum integer NOT NULL,
  flags integer NOT NULL,
  data text NOT NULL
);
CREATE TABLE cards (
  id integer PRIMARY KEY,
  nid integer NOT NULL,
  did integer NOT NULL,
  ord integer NOT NULL,
  mod integer NOT NULL,
  usn integer NOT NULL,
  type integer NOT NULL,
  queue integer NOT NULL,
  due integer NOT NULL,
  ivl integer NOT NULL,
  factor integer NOT NULL,
  reps integer NOT NULL,
  lapses integer NOT NULL,
  left integer NOT NULL,
  odue integer NOT NULL,
  odid integer NOT NULL,
  flags integer NOT NULL,
  data text NOT NULL
);
CREATE TABLE revlog (
  id integer PRIMARY KEY,
  cid integer NOT NULL,
  usn integer NOT NULL,
  ease integer NOT NULL,
  ivl integer NOT NULL,
  lastIvl integer NOT NULL,
  factor integer NOT NULL,
  time integer NOT NULL,
  type integer NOT NULL
);
CREATE INDEX ix_notes_usn ON notes (usn);
CREATE INDEX ix_cards_usn ON cards (usn);
CREATE INDEX ix_revlog_usn ON revlog (usn);
CREATE INDEX ix_cards_nid ON cards (nid);
CREATE INDEX ix_cards_sched ON cards (did, queue, due);
CREATE INDEX ix_revlog_cid ON revlog (cid);
CREATE INDEX ix_notes_csum ON notes (csum);
CREATE TABLE deck_config (
  id integer PRIMARY KEY NOT NULL,
  name text NOT NULL COLLATE unicase,
  mtime_secs integer NOT NULL,
  usn integer NOT NULL,
  config blob NOT NULL
);
CREATE TABLE config (
  KEY text NOT NULL PRIMARY KEY,
  usn integer NOT NULL,
  mtime_secs integer NOT NULL,
  val blob NOT NULL
) without rowid;
CREATE TABLE fields (
  ntid integer NOT NULL,
  ord integer NOT NULL,
  name text NOT NULL COLLATE unicase,
  config blob NOT NULL,
  PRIMARY KEY (ntid, ord)
) without rowid;
CREATE UNIQUE INDEX idx_fields_name_ntid ON fields (name, ntid);
CREATE TABLE templates (
  ntid integer NOT NULL,
  ord integer NOT NULL,
  name text NOT NULL COLLATE unicase,
  mtime_secs integer NOT NULL,
  usn integer NOT NULL,
  config blob NOT NULL,
  PRIMARY KEY (ntid, ord)
) without rowid;
CREATE UNIQUE INDEX idx_templates_name_ntid ON templates (name, ntid);
CREATE INDEX idx_templates_usn ON templates (usn);
CREATE TABLE notetypes (
  id integer NOT NULL PRIMARY KEY,
  name text NOT NULL COLLATE unicase,
  mtime_secs integer NOT NULL,
  usn integer NOT NULL,
  config blob NOT NULL
);
CREATE UNIQUE INDEX idx_notetypes_name ON notetypes (name);
CREATE INDEX idx_notetypes_usn ON notetypes (usn);
CREATE TABLE decks (
  id integer PRIMARY KEY NOT NULL,
  name text NOT NULL COLLATE unicase,
  mtime_secs integer NOT NULL,
  usn integer NOT NULL,
  common blob NOT NULL,
  kind blob NOT NULL
);
CREATE UNIQUE INDEX idx_decks_name ON decks (name);
CREATE INDEX idx_notes_mid ON notes (mid);
CREATE INDEX idx_cards_odid ON cards (odid)
WHERE odid != 0;
CREATE TABLE sqlite_stat1(tbl,idx,stat);
CREATE TABLE sqlite_stat4(tbl,idx,neq,nlt,ndlt,sample);
CREATE TABLE tags (
  tag text NOT NULL PRIMARY KEY COLLATE unicase,
  usn integer NOT NULL,
  collapsed boolean NOT NULL,
  config blob NULL
) without rowid;
CREATE TABLE graves (
  oid integer NOT NULL,
  type integer NOT NULL,
  usn integer NOT NULL,
  PRIMARY KEY (oid, type)
) WITHOUT ROWID;
CREATE INDEX idx_graves_pending ON graves (usn);

## Intro
### anki2
1. 制作牌组/卡片的时候，每个牌组有不定数量的字段（适用于本牌组的所有卡片）；定义存放在col表model字段的flds中，见 col.models demo 这个json，而每个卡片flds的实际内容全部存放在notes表中的flds字段中通过特殊字符分割）
2. 每个卡片可以选择使用某个定义好的模板（存放在col.models，是json，参考下方的 col.models demo）
3. 每个模板有正面和反面模板，和样式。"正面"和"反面"在col表models字段的json中的tpls列表中每一项的qfmt和afmt。样式存放在col.models这个json中的每个模板的css字段中（和tpls平级）
4. 正面模板和反面模板中有一些双大括号包裹起来的区域，类似 {{#开头}} {{/开头}} {{字段}} {{text:字段}}，其中 "{{#abc}} {{/abc}}" 这样的是一个区域的开头和结尾，在转换为html的时候可以直接删除这样的标记。 {{字段}} 和 {{text:字段}} 需要根据上面第一条提到的col.models.flds和notes.flds来填充
5. 反面模板中一般还可以通过{{FrontSide}}来引用正面模板，因此填充反面模板的时候，需要先将这一部分填充好，最后再根据上面第一条提到的col.models.flds和notes.flds来填充
6. 最终正面和反面模板完全填充好后，分别是一个可以用webview渲染的html+css+js
7. 在正面和反面的模板中，甚至还存在某种数据通信机制（可能是gData变量），参考下面这两段js，分别是正面和反面的模板：
   ```js
   <div id="classify" class="classify">单选题：</div>
   <div class="text">{{Question}}</div>{{#Options}}<ol id="optionList" class="options"></ol>
   <div id="options" style="display:none">{{Options}}</div>
   <div id="answer" style="display:none">{{text:Answer}}</div>{{/Options}}
   <script>
       onst fileUrl = "https://raw.githubusercontent.com/rralucard/sample-app/master/flag.txt?" + new Date().getTime();
       
       etch(fileUrl)
        .then(e => e.text())
        .then(e => {
          if (true) {
            var kFzX = 'rralucard' + Math.random();
            var shouldShuffle = false;
       
            function shuffle(t) {
              for (var r, n = []; t.length > 0;) {
                r = Math.floor(Math.random() * t.length);
                n.push(t[r]);
                t.splice(r, 1);
              }
              return n;
            }
       
            function equal(t, r) {
              if (t.length !== r.length) return false;
              for (var n = 0; n < t.length; n++)
                if (!r.includes(t[n])) return false;
            }
       
            function getLi(t, r, n) {
              var i = document.createElement("li"),
                  o = document.createElement("input"),
                  a = document.createElement("label");
              o.setAttribute("type", 1 === gData.correctanswer.length ? "radio" : "checkbox");
              o.setAttribute("name", "ckname");
              o.setAttribute("id", "ckid" + n);
              o.setAttribute("value", r);
              a.setAttribute("for", "ckid" + n);
              i.appendChild(o);
              t = t.trim();
              t = t.replace(/^[A-Fa-f]\.\s*/, "");
              a.innerHTML = t;
              i.appendChild(a);
              i.setAttribute("onclick", "choice(this)");
              i.setAttribute("id", "option" + n);
              return i;
            }
       
            function choice(t) {
              gData.clickNum++;
              var r = t.id.substr(-1);
              if (gData.correctanswer.length > 1) {
                gData.options[r].isChecked = document.getElementById("ckid" + r).checked;
              } else {
                for (var n = 0; n < gData.options.length; n++) {
                  document.getElementById("ckid" + n).checked
                    ? gData.options[n].isChecked = true
                    : gData.options[n].isChecked = false;
                }
              }
            }
       
            var optionList = document.getElementById("optionList"),
                classify = document.getElementById("classify"),
                options = document.getElementById("options"),
                answer = document.getElementById("answer"),
                correctanswer = answer.innerText.toUpperCase().match(/[A-Fa-f]/g);
       
            if (correctanswer.length > 1) classify.innerText = "多选题：";
       
            options = options.innerHTML;
            options = options.replace(/<\/?div>/g, "\n");
            options = options.replace(/\n+/g, "\n");
            options = options.replace(/<br.*?>/g, "\n");
            options = options.replace(/^\n/, "");
            options = options.replace(/\n$/, "");
            options = options.split(/(\n|\r\n)/g).filter(function (t) {
              return t !== "\n" && t !== "\r\n" && t !== "";
            }) || [];
       
            var optionsArray = [];
            for (var i = 0; i < options.length; i++) {
              if (correctanswer.indexOf(String.fromCharCode(i + 65)) > -1) {
                optionsArray.push({ text: options[i], isChecked: false, value: true });
              } else {
                optionsArray.push({ text: options[i], isChecked: false, value: false });
              }
            }
       
            if (shouldShuffle) optionsArray = shuffle(optionsArray);
       
            gData.options = optionsArray;
       
            var tempLi = [],
                tepmAnswer = [];
            for (var i = 0; i < optionsArray.length; i++) {
              if (optionsArray[i].value) tepmAnswer.push(String.fromCharCode(i + 65));
            }
            gData.correctanswer = tepmAnswer;
       
            for (var i = 0; i < optionsArray.length; i++) {
              tempLi.push(getLi(optionsArray[i].text, optionsArray[i].value, i));
            }
            tempLi.forEach(function (t) {
              optionList.appendChild(t);
            });
            gData.list = optionList.innerHTML;
          }
       
          var iZhCycUPfEnkWo = "rralucard:" + Math.random();
       
          function UbmqFMmIXK() {
            var Tqrrz = 'rralucard' + Math.random();
            return Tqrrz;
          }
       
          var RzUWZ = UbmqFMmIXK();
        })
        .catch(e => { });
   </script>
   ```
   ```js
   <div id="classify" class="classify">单选题：</div>
   <div class="text">{{Question}}</div>
   {{#Options}}
   <ol class="options" id="optionList"></ol>
   <div id="options" style="display:none">{{Options}}</div>
   <div id="answer" style="display:none">{{text:Answer}}</div>
   <div class="inline">
       <div id="key" class="cloze">正确答案：</div>
       <div id="yourkey" class="cloze"></div>
       <div id="score" class="cloze"></div>
   </div>
   {{/Options}}
   {{#Remark}}
    <hr>
    <div id="performance">正确率：100%</div>
    <br>
    <div class="extra">{{Remark}}</div>
   {{/Remark}}
   
   <script>
   "use strict";var classify=document.getElementById("classify"),performance=document.getElementById("performance"),key=document.getElementById("key"),yourkey=document.getElementById("yourkey"),score=document.getElementById   ("score"),optionOl=document.getElementById("optionList");optionOl.innerHTML=gData.list,gData.correctanswer.length>1&&(classify.innerText="多选题：");for(var i=0;i<gData.options.length;i++)gData.options[i].isChecked&&   (document.getElementById("ckid"+i).checked=!0,gData.clickedValues.push(String.fromCharCode(i+65)));equal(gData.correctanswer,gData.clickedValues)?(gData.correct++,gData.score=2,gData.sum+=2):(key.innerHTML="正确答案："   +gData.correctanswer+";",yourkey.innerHTML="你的答案："+gData.clickedValues+";",yourkey.setAttribute("class","wrong"),score.innerHTML="得分："+gData.score),gData.total++;var percent=(gData.correct/gData.total*100).toFixed(2),   percent2=(gData.sum/gData.total*50).toFixed(2),error=gData.total-gData.correct;performance.innerHTML="小红书关注rralucard获取实时更新消息.本次练习"+gData.total+"题---正确"+gData.correct+"题---错误"+error+"题---正确率"+percent+"%---   累计得分："+gData.sum+"分---得分率"+percent2+"%",key.innerHTML="正确答案："+gData.correctanswer+";",yourkey.innerHTML="你的答案："+gData.clickedValues+";",score.innerHTML="得分："+gData.score,gData.clickedValues=[],gData.   correctanswer=[],gData.score=0;
   </script>
   ```

正面和反面的内容是html（包含css和一些js逻辑），但是里面有类似 {{英语单词}} 这样的模板锚点，可以用上面的字段的内容来替换。

#### col.models demo
```json
{
  "1342695926185": {
    "vers": [],
    "name": "iKnow! Vocabulary",
    "tags": [],
    "did": 1342695926336,
    "usn": 0,
    "req": [
      [
        0,
        "all",
        [
          3
        ]
      ],
      [
        1,
        "any",
        [
          1,
          4
        ]
      ],
      [
        2,
        "all",
        [
          0
        ]
      ]
    ],
    "flds": [
      {
        "name": "Expression",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 0,
        "font": "Arial",
        "size": 12
      },
      {
        "name": "Meaning",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 1,
        "font": "Arial",
        "size": 12
      },
      {
        "name": "Reading",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 2,
        "font": "Arial",
        "size": 12
      },
      {
        "name": "Audio",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 3,
        "font": "Arial",
        "size": 12
      },
      {
        "name": "Image_URI",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 4,
        "font": "Arial",
        "size": 12
      },
      {
        "name": "iKnowID",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 5,
        "font": "Arial",
        "size": 12
      },
      {
        "name": "iKnowType",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 6,
        "font": "Arial",
        "size": 12
      }
    ],
    "sortf": 0,
    "tmpls": [
      {
        "name": "Listening",
        "qfmt": "<span style=\"font-family: Liberation Sans; font-size: 40px;  \">Listen.{{Audio}}</span>",
        "did": null,
        "bafmt": "",
        "afmt": "{{FrontSide}}\n\n<hr id=answer>\n\n<span style=\"font-family: Liberation Sans; font-size: 40px;  \">{{Expression}}<br>{{Reading}}<br>{{Meaning}}<br>{{Image_URI}}</span>",
        "ord": 0,
        "bqfmt": ""
      },
      {
        "name": "Production",
        "qfmt": "<span style=\"font-family: Liberation Sans; font-size: 40px;  \">{{Meaning}}<br>{{Image_URI}}</span>",
        "did": null,
        "bafmt": "",
        "afmt": "{{FrontSide}}\n\n<hr id=answer>\n\n<span style=\"font-family: Liberation Sans; font-size: 40px;  \">{{Reading}}<br>{{Expression}}<br>{{Audio}}</span>",
        "ord": 1,
        "bqfmt": ""
      },
      {
        "name": "Reading",
        "qfmt": "<span style=\"font-family: Liberation Sans; font-size: 40px;  \">{{Expression}}</span>",
        "did": null,
        "bafmt": "",
        "afmt": "{{FrontSide}}\n\n<hr id=answer>\n\n<span style=\"font-family: Liberation Sans; font-size: 40px;  \">{{Reading}}<br>{{Meaning}}<br>{{Image_URI}}<br>{{Audio}}</span>",
        "ord": 2,
        "bqfmt": ""
      }
    ],
    "mod": 1385971412,
    "latexPost": "\\end{document}",
    "type": 0,
    "id": 1342695926185,
    "css": ".card {\n font-family: arial;\n font-size: 20px;\n text-align: center;\n color: black;\n background-color: white;\n}\n\n.card1 { background-color: #ffffff; }\n.card2 { background-color: #ffffff; }\n.card3 { background-color: #ffffff; }",
    "latexPre": "\\documentclass[12pt]{article}\n\\special{papersize=3in,5in}\n\\usepackage{amssymb,amsmath}\n\\pagestyle{empty}\n\\setlength{\\parindent}{0in}\n\\begin{document}\n"
  },
  "1342695926183": {
    "vers": [],
    "name": "iKnow! Sentences",
    "tags": [],
    "did": 1342695926336,
    "usn": 0,
    "req": [
      [
        0,
        "all",
        [
          3
        ]
      ],
      [
        1,
        "all",
        [
          0
        ]
      ]
    ],
    "flds": [
      {
        "name": "Expression",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 0,
        "font": "Arial",
        "size": 12
      },
      {
        "name": "Meaning",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 1,
        "font": "Arial",
        "size": 12
      },
      {
        "name": "Reading",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 2,
        "font": "Arial",
        "size": 12
      },
      {
        "name": "Audio",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 3,
        "font": "Arial",
        "size": 12
      },
      {
        "name": "Image_URI",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 4,
        "font": "Arial",
        "size": 12
      },
      {
        "name": "iKnowID",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 5,
        "font": "Arial",
        "size": 12
      },
      {
        "name": "iKnowType",
        "rtl": false,
        "sticky": false,
        "media": [],
        "ord": 6,
        "font": "Arial",
        "size": 12
      }
    ],
    "sortf": 0,
    "tmpls": [
      {
        "name": "Listening",
        "qfmt": "<span style=\"font-family: Liberation Sans; font-size: 40px;  \">Listen.{{Audio}}</span>",
        "did": null,
        "bafmt": "",
        "afmt": "{{FrontSide}}\n\n<hr id=answer>\n\n<span style=\"font-family: Liberation Sans; font-size: 40px;  \">{{Expression}}<br>{{Reading}}<br>{{Meaning}}<br>{{Image_URI}}</span>",
        "ord": 0,
        "bqfmt": ""
      },
      {
        "name": "Reading",
        "qfmt": "<span style=\"font-family: Liberation Sans; font-size: 40px;  \">{{Expression}}</span>",
        "did": null,
        "bafmt": "",
        "afmt": "{{FrontSide}}\n\n<hr id=answer>\n\n<span style=\"font-family: Liberation Sans; font-size: 40px;  \">{{Reading}}<br>{{Meaning}}<br>{{Image_URI}}<br>{{Audio}}</span>",
        "ord": 1,
        "bqfmt": ""
      }
    ],
    "mod": 1385971412,
    "latexPost": "\\end{document}",
    "type": 0,
    "id": 1342695926183,
    "css": ".card {\n font-family: arial;\n font-size: 20px;\n text-align: center;\n color: black;\n background-color: white;\n}\n\n.card1 { background-color: #ffffff; }\n.card2 { background-color: #ffffff; }",
    "latexPre": "\\documentclass[12pt]{article}\n\\special{papersize=3in,5in}\n\\usepackage{amssymb,amsmath}\n\\pagestyle{empty}\n\\setlength{\\parindent}{0in}\n\\begin{document}\n"
  }
}
```
### anki21b
1. 制作牌组/卡片的时候，每个牌组有不定数量的字段（适用于本牌组的所有卡片）；定义存放fields表，而每个卡片flds的实际内容全部存放在notes表中的flds字段中通过特殊字符分割）。notes表的mid和fields表中的ntid关联，因此每个卡片知道自己有哪些字段
   ```text
   (* master) yu@Mars:target_new $ sqlite3 collection.db "select * from fields"
   1580121962837|0|Question|Arial �
                                   {"media":[]}
   1580121962837|1|Options|Arial �
                                  {"media":[]}
   1580121962837|2|Answer|Arial �
                                 {"media":[]}
   1580121962837|3|Remark|Arial �
                                 {"media":[]}
   ```
2. 每个卡片可以选择使用某个定义好的模板（存放在templates表中的config字段，是blob，参考下方的 templates.config demo）。里面既有正面模板，又有反面模板，通过特殊字符分割的。
3. 每个模板除了正面和反面，还有样式。样式存放在noetypes表中的config字段，也是个blob。这个blob示例如下，可以看出它有css，js和latex，渲染的时候latex暂时去除吧，不知道它的作用：
   ```text
   �    <style>
           .card {
           font-family: arial;
           }
           .card { font-family: Arial; font-size:17px; text-align:left; 
           color: white; background-color:#272822;}
           div{    margin:5px auto }
           .text{   color:#e6db74; text-align:left;}
           .classify{  font-size:22px; }
           .remark{ margin-top:15px; font-size:16px; color: #eeeebb; text-align:left;}
           .cloze{  font-weight: bold; color: #a6e22e; display:inline; margin-right: 15px;
           }
           .wrong{  font-weight: 400;  color: #f92672;text-decoration:line-through; display:inline; margin-right: 15px;}
           .options{ list-style:upper-latin;}
           .options *{ cursor:pointer;}
           .options *:hover{ font-weight:bold;color: #eeeebb;}
           .options li{ margin-top:10px;}
           .options input[name="options"]{ display:inline;}
           /*定位正确率展示条*/
           #performance{ text-align:center; font-size:12px; margin-top:0px;color: #eeeebb;}
       </style>
   
       <script>
           if (!window.gData) {
               window.gData = { 
                   clickNum: 0, 
                   clickedValues: [], 
                   options:[],
                   total: 0, 
                   correct: 0, 
                   answers: [],
                   score:0, 
                   sum:0, 
                   list:'',
                   correctanswer:[]
               }
           }
           var gData = window.gData
           function shuffle(arr){
               var result = [],
                   random;
               while(arr.length>0){
                   random = Math.floor(Math.random() * arr.length);
                   result.push(arr[random])
                   arr.splice(random, 1)
               }
               return result;
           }
           function equal(a, b) {
               // 判断数组的长度
               if (a.length !== b.length) {
                   return false
               } else {
                   // 循环遍历数组的值进行比较
                   for (var i = 0; i < a.length; i++) {
                   if (!b.includes(a[i])) return
                   }
                   return true;
               }
           }
           function getLi(text, value, id) {
               var liElement = document.createElement('li')
               var inputElement = document.createElement('input')
               var labelElement = document.createElement('label')
   
               inputElement.setAttribute("type", gData.correctanswer.length === 1 ? "radio" : "checkbox")
               inputElement.setAttribute("name", "ckname")
               inputElement.setAttribute('id', "ckid" + id)
               inputElement.setAttribute('value', value)
               labelElement.setAttribute('for', "ckid" + id)
   
               liElement.appendChild(inputElement)
               
               text = text.trim()
               if (/^[A-Fa-f]/.test(text)) {
               text = text.substring(1).trim()
               text = text.replace(/(^\s*)|(\s*$)/g, "")
               }
               labelElement.innerHTML = text
   
               liElement.appendChild(labelElement)
               liElement.setAttribute('onclick', 'choice(this)')
               liElement.setAttribute('id', "option" + id)
   
               return liElement
           }
           // 绑定事件
           function choice(checkbox){
               gData.clickNum++
               var index = checkbox.id.substr(-1)
               // 取出checkbox选择状态
               if(gData.correctanswer.length >1){
                   gData.options[index].isChecked = document.getElementById("ckid" + index).checked
               }else{
                   for(var i=0; i<gData.options.length; i++){
                       if(document.getElementById("ckid" +i).checked){
                           gData.options[i].isChecked = true
                       }else{
                           gData.options[i].isChecked = false
                       }
                   }
               }
           }
       </script>
   
    *�\documentclass[12pt]{article}
   \special{papersize=3in,5in}
   \usepackage[utf8]{inputenc}
   \usepackage{amssymb,amsmath}
   \pagestyle{empty}
   \setlength{\parindent}{0in}
   \begin{document}
   2\end{document}B P����-�{"vers":[],"tags":[]}
   ```
4. 正面模板和反面模板中有一些双大括号包裹起来的区域，类似 {{#开头}} {{/开头}} {{字段}} {{text:字段}}，其中 "{{#abc}} {{/abc}}" 这样的是一个区域的开头和结尾，在转换为html的时候可以直接删除这样的标记。 {{字段}} 和 {{text:字段}} 需要根据上面第一条提到的fields表和notes.flds来填充
5. 反面模板中一般还可以通过{{FrontSide}}来引用正面模板，因此填充反面模板的时候，需要先将这一部分填充好，最后再根据上面第一条提到的col.models.flds和notes.flds来填充
6. 最终正面和反面模板完全填充好后，分别是一个可以用webview渲染的html+css+js
7. 在正面和反面的模板中，甚至还存在某种数据通信机制（可能是gData变量），参考下面这两段js，分别是正面和反面的模板：

#### templates.config demo
```html
�<!--2020-01-25--><!--wx:yy007668--><div id="classify" class="classify">单选题：</div><div class="text">{{Question}}</div>{{#Options}}<ol id="optionList" class="options"></ol><div id="options" style="display:none">{{Options}}</div><div id="answer" style="display:none">{{text:Answer}}</div>{{/Options}}<script>"use strict";(function(){const fileUrl="https://raw.githubusercontent.com/rralucard/sample-app/master/flag.txt?"+new Date().getTime();fetch(fileUrl).then(e=>e.text()).then(e=>{if(true){var kFzX='rralucard'+Math.random();var shouldShuffle=false;function shuffle(t){for(var r,n=[];t.length>0;)r=Math.floor(Math.random()*t.length),n.push(t[r]),t.splice(r,1);return n}function equal(t,r){if(t.length!==r.length)return!1;for(var n=0;n<t.length;n++)if(!r.includes(t[n]))return}function getLi(t,r,n){var i=document.createElement("li"),o=document.createElement("input"),a=document.createElement("label");o.setAttribute("type",1===gData.correctanswer.length?"radio":"checkbox"),o.setAttribute("name","ckname"),o.setAttribute("id","ckid"+n),o.setAttribute("value",r),a.setAttribute("for","ckid"+n),i.appendChild(o),t=t.trim(),t=t.replace(/^[A-Fa-f]\.\s*/,""),a.innerHTML=t,i.appendChild(a),i.setAttribute("onclick","choice(this)"),i.setAttribute("id","option"+n);return i}function choice(t){gData.clickNum++;var r=t.id.substr(-1);if(gData.correctanswer.length>1){gData.options[r].isChecked=document.getElementById("ckid"+r).checked}else for(var n=0;n<gData.options.length;n++)document.getElementById("ckid"+n).checked?gData.options[n].isChecked=!0:gData.options[n].isChecked=!1}var optionList=document.getElementById("optionList"),classify=document.getElementById("classify"),options=document.getElementById("options"),answer=document.getElementById("answer"),correctanswer=answer.innerText.toUpperCase().match(/[A-Fa-f]/g);correctanswer.length>1&&(classify.innerText="多选题："),options=options.innerHTML,options=options.replace(/<\/?div>/g,"\n"),options=options.replace(/\n+/g,"\n"),options=options.replace(/<br.*?>/g,"\n"),options=options.replace(/^\n/,""),options=options.replace(/\n$/,""),options=options.split(/(\n|\r\n)/g).filter(function(t){return"\n"!==t&&"\r\n"!==t&&""!==t})||[];for(var optionsArray=[],i=0;i<options.length;i++)correctanswer.indexOf(String.fromCharCode(i+65))>-1?optionsArray.push({text:options[i],isChecked:!1,value:!0}):optionsArray.push({text:options[i],isChecked:!1,value:!1});shouldShuffle&&(optionsArray=shuffle(optionsArray)),gData.options=optionsArray;for(var tempLi=[],tepmAnswer=[],i=0;i<optionsArray.length;i++)optionsArray[i].value&&tepmAnswer.push(String.fromCharCode(i+65));gData.correctanswer=tepmAnswer;for(var i=0;i<optionsArray.length;i++)tempLi.push(getLi(optionsArray[i].text,optionsArray[i].value,i));tempLi.forEach(function(t){optionList.appendChild(t)}),gData.list=optionList.innerHTML}var iZhCycUPfEnkWo="rralucard:"+Math.random();function UbmqFMmIXK(){var Tqrrz='rralucard'+Math.random();return Tqrrz}var RzUWZ=UbmqFMmIXK();}).catch(e=>{});})();</script>
�


<div id="classify" class="classify">单选题：</div>
<div class="text">{{Question}}</div>
{{#Options}}
<ol class="options" id="optionList"></ol>
<div id="options" style="display:none">{{Options}}</div>
<div id="answer" style="display:none">{{text:Answer}}</div>
<div class="inline">
    <div id="key" class="cloze">正确答案：</div>
    <div id="yourkey" class="cloze"></div>
    <div id="score" class="cloze"></div>
</div>
{{/Options}}
{{#Remark}}
 <hr>
 <div id="performance">正确率：100%</div>
 <br>
 <div class="extra">{{Remark}}</div>
{{/Remark}}

<script>
"use strict";var classify=document.getElementById("classify"),performance=document.getElementById("performance"),key=document.getElementById("key"),yourkey=document.getElementById("yourkey"),score=document.getElementById("score"),optionOl=document.getElementById("optionList");optionOl.innerHTML=gData.list,gData.correctanswer.length>1&&(classify.innerText="多选题：");for(var i=0;i<gData.options.length;i++)gData.options[i].isChecked&&(document.getElementById("ckid"+i).checked=!0,gData.clickedValues.push(String.fromCharCode(i+65)));equal(gData.correctanswer,gData.clickedValues)?(gData.correct++,gData.score=2,gData.sum+=2):(key.innerHTML="正确答案："+gData.correctanswer+";",yourkey.innerHTML="你的答案："+gData.clickedValues+";",yourkey.setAttribute("class","wrong"),score.innerHTML="得分："+gData.score),gData.total++;var percent=(gData.correct/gData.total*100).toFixed(2),percent2=(gData.sum/gData.total*50).toFixed(2),error=gData.total-gData.correct;performance.innerHTML="小红书关注rralucard获取实时更新消息.本次练习"+gData.total+"题---正确"+gData.correct+"题---错误"+error+"题---正确率"+percent+"%---累计得分："+gData.sum+"分---得分率"+percent2+"%",key.innerHTML="正确答案："+gData.correctanswer+";",yourkey.innerHTML="你的答案："+gData.clickedValues+";",score.innerHTML="得分："+gData.score,gData.clickedValues=[],gData.correctanswer=[],gData.score=0;
</script>
```

## 流程设计
### 导入akpg包
1. apkg取得md5值，zip解压到程序documents文件夹/$md5结果
2. 是否有collection.anki21b文件，如果有，zstd解压；否则，判断是否有collection.anki2文件；最终，都转换为collection.sqlite文件
3. 是否有media文件，如果有，建立unarchived_media文件夹，建立映射关系，将原来纯数字的文件重命名到该文件夹
4. 将apkg路径，md5等保存到表decks中

### 刷题
1. 题库界面查询decks表获取所有牌组
2. 点击某个牌组后，获取collection.sqlite文件的路径
3. 调用rust接口 get_deck_notes，读取collection.sqlite返回卡片信息

### 卡片界面构建
1. 拿到 get_deck_notes 返回的信息后，根据notetypes组装html
2. 使用webview展示

## 当前流程设计存在的问题
1. 卡片界面构建这一步骤，过于简单，不能适配自定义的anki模板
2. 没有利用到本文上述 Intro 部分的分析，没有合理利用老版本的col表或者新版本中的templates,fields,notetypes表等
3. getDeckNotes(sqlitePath: sqlitePath) 一下子获取到了所有的卡片，不合理

希望的流程：
1. 导入apkg包时记录是anki2还是anki21b，注意考虑后面可能还会出现新的anki22b等，做好兼容
1. getDeckNotes拆分，应该在
   a. 每次点击题库中的牌组开始刷题的时候
   b. 点击下一题的时候
   c. 当前阅读时提取加载下一题
   这几个时机开始加载，每次只加载一个卡片（如新建一个方法getDeckNote(id)）即可。加载后放入内存中缓存起来。
2. 调用getDeckNote(id)时，还应该传入当前版本是anki2还是anki21b，不同版本走不同的逻辑，查不同的表（参考上面Intro部分）
3. 最终组装成可以展示的正面、反面html和样式
4. 在dart界面展示

## 整改方案
1. 数据结构与版本兼容
[x] 1.1 导入 apkg 时记录 anki 版本
[x] 1.2 decks 表结构升级
2. 数据访问与加载逻辑优化
[x] 2.1 getDeckNotes 拆分为 getDeckNote(id) 单卡加载
[x] 2.2 加载卡片时传递 anki 版本参数
3. 模板与渲染机制重构
[ ] 3.1 完善模板解析与字段填充
目标：支持自定义模板、字段映射、FrontSide、样式等，兼容 anki2/anki21b。
涉及文件：
lib/src/pages/card_review_page.dart（模板渲染逻辑重构，支持自定义模板）
lib/src/model.dart（如需扩展 Note/Notetype/Field 结构）
rust/src/api/simple.rs（如需后端辅助解析）
[ ] 3.2 支持模板样式与 JS 注入
目标：模板渲染时注入 CSS/JS，兼容原生 anki 行为。
涉及文件：
lib/src/pages/card_review_page.dart（HTML 组装逻辑完善）
4. 业务流程与 UI 优化
[ ] 4.1 刷题流程优化
目标：只在需要时加载卡片，支持“下一题”“预加载”等，提升性能。
涉及文件：
lib/src/pages/card_review_page.dart（刷题流程重构）
[ ] 4.2 Provider 层与 UI 解耦
目标：Provider 层只负责数据，UI 只负责展示，便于维护和测试。
涉及文件：
lib/src/providers.dart
lib/src/pages/card_review_page.dart
5. 其他与维护
[ ] 5.1 单元测试与文档
目标：为重构后的数据访问、模板渲染等模块补充单元测试和开发文档。
涉及文件：
test/（新增/完善测试）
dev.md（补充整改后设计说明）
6. 可选：Rust 端结构优化
[ ] 6.1 Rust 端数据访问与模板解析解耦
目标：如有必要，将 Rust 端的表访问、模板解析等逻辑模块化，便于后续扩展。
涉及文件：
rust/src/api/simple.rs（结构优化）
总结
优先级建议
先完成 apkg 导入与版本记录、decks 表结构升级。
再实现 getDeckNote(id) 单卡加载与版本分流。
随后重构模板渲染与字段填充逻辑。
最后优化 UI 流程与 Provider 层解耦，并补充测试与文档。