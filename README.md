# Similarity-Join

Some modification in resourse code of postgreSQL-9.1.3

---

## 实验内容
阅读理解PostgreSQL数据库源码，修改源码，添加两个函数计算levenshtein_distance和jaccard_index，体会数据库查询的底层原理。
1. Levenshtein Distance (编辑距离)
编辑距离是指从字符串a变化到字符串b的最小操作距离。在这里定义三个操作：插入，删除，替换。插入一个字符、删除一个字符和替换一个字符的的操作次数都是1。编辑距离越小证明两个字符串相似度越高。通过动态规划的方法实现该算法
2. Jaccard Index (Jaccard 相似系数)
Jaccard系数的计算方法是，把字符串A和B分别拆成二元组的集合，首字符和和尾字符分别用`$`在开头和结尾连接成一个二元组，如 “apple” -> {$a, ap, pp, pl, le, e$}, “apply” -> {$a, ap, pp, pl, ly, y$}，然后计算两个集合的交集除以两个集合的并集得到结果。结果越大证明两个字符串相似度越高。该算法可以用哈希表实现。

---

## 开发环境
VirtualBox Ubuntu（64bit）,WSL,PostgreSQL9.1.3

---
## PostgreSQL下载配置

在后续添加函数修改函数过程中出现无法找到函数的问题：经过与助教老师讨论以及搜索查找结果得知在pg_proc.h中注册新函数后，以下三个文件会在编译后生成对应的新函数内容：
<p>a.	src/backend/catalog/postgres.bki</p>
<p>b.	src/backend/utils/fmgroids.h</p>
<p>c.	src/backend/utils/fmgrtab.c</p>
但是在已经编译一次后再次编译这些文件中的新增内容并不会生效，故每次修改函数内容后都需要断连网络删库重新配置编译安装连接
以下为每次修改重新配置编译安装连接数据库的脚本文件代码（删库跑路大法好）：

```
$HOME/pgsql/bin/pg_ctl -D $HOME/pgsql/data -l logfile stop
rm -r $HOME/pgsql
./configure --enable-depend --enable-cassert --enable-debug CFLAGS="-O0" --prefix=$HOME/pgsql --without-readline --without-zlib
make
make install
$HOME/pgsql/bin/initdb -D $HOME/pgsql/data --locale=C
$HOME/pgsql/bin/pg_ctl -D $HOME/pgsql/data -l logfile start
$HOME/pgsql/bin/psql -p 5432 postgres -c 'CREATE DATABASE similarity;'
$HOME/pgsql/bin/psql -p 5432 -d similarity -f $HOME/DatabasePJ/similarity_data.sql
$HOME/pgsql/bin/psql similarity
```

---

## 关键代码文件解释
- src/backend/executor/execMain.c
<br>执行ExecutorStart()、ExecutorRun()、ExecutorFinish()、ExecutorEnd()四个函数，执行计划查询
- src/backend/executor/execProcnode.c
<br>为给定节点类型调用适当的初始化、获取元组、清理的函数
- src/backend/executor/execScan.c
<br>对关系进行扫描，并传递节点和指向函数的指针，检查返回元组是否满足条件，并根据查询语句进行投影
- src/backend/executor/execTuples.c
<br>处理元组表的例程。它们用于与元组相关的资源管理(例如，释放磁盘缓冲区中元组的缓冲引脚，或释放被瞬态元组占用的内存)。槽还提供访问抽象，使我们能够实现“虚拟”元组，以减少数据复制开销。
上述为执行器的主要文件，以下为本次需要操作的文件
- src/backend/utils/fmgr/funcapi.c
<br>函数主体所在文件，levenshtein_distance和jaccard_index函数需要添加在此处
- src/include/catalog/pg_proc.h
<br>注册添加函数，为其定义名字空间以及一些属性
- src/include/utils/builtins.h
<br>声明外部函数

---
## 修改代码分析

- src/include/utils/builtins.h:
<br>声明外部函数
<br>![图片](https://github.com/Indifference061/Similarity-Join/assets/87850383/e9e5c4ca-220f-4eb7-973e-5272f456aa07)


- src/include/catalog/pg_proc.h
<br>注册名字空间，OID需要成为函数的唯一标识不可与其余函数的OID重复，故只要保证与其他OID不同即可，其余参数需要与开头定义的结构体相一致，各个参数的表示内容如下：
<br>![图片](https://github.com/Indifference061/Similarity-Join/assets/87850383/f88eaca1-6cd7-4332-a81b-6d2f9c34e4a0)
<br>添加内容：
<br>![图片](https://github.com/Indifference061/Similarity-Join/assets/87850383/284bead1-2769-4661-84a0-98e6d47f4d0f)

### levenshtein_distance:
通过动态规划，用 d[i][j] 表示s1 的前 i 个字母和 S2 的前 j 个字母之间的编辑距离：
<br>①若s1的第i个字符不等于s2的第j个字符，即s1[i-1]!=s2[j-1]:
- d[i][j-1] 为s1的前i个字符和s2的前j-1个字符编辑距离的子问题。即对于s2的第j个字符，在s2的末尾添加了一个相同的字符，那么d[i][j]最小可以为d[i][j-1]+1；
- d[i-1][j] 为 S1 的前 i - 1 个字符和 S2 的前 j 个字符编辑距离的子问题。即对于 S1 的第 i 个字符，我们在 S2 的末尾添加了一个相同的字符，那么d[i][j] 最小可以为d[i-1][j] + 1；
- d[i-1][j-1] 为 S1 前 i - 1 个字符和 S2 的前 j - 1 个字符编辑距离的子问题。即对于 S2 的第 j 个字符，我们修改 S1 的第 i 个字符使它们相同，那么d[i][j] 最小可以为d[i-1][j-1] + 1。特别地，如果 S1 的第 i 个字符和 S2 的第 j 个字符原本就相同，那么我们实际上不需要进行修改操作。在这种情况下，d[i][j] 最小可以为d[i-1][j-1]。

<br>②若s1的第i个字符等于s2的第j个字符，即s1[i-1]==s2[j-1]：则无需在i-1，j-1的基础上进行编辑，故d[i][j]=d[i-1][j-1]
<br>![图片](https://github.com/Indifference061/Similarity-Join/assets/87850383/0d7fb47c-430d-45be-ae40-0d14fe852ffa)
<p>算法性能 ：
初始化数组有O（m+n）的时间复杂度；对于每⼀次计算，复杂度都为 O( m * n )；使⽤静态数组可以免去每次查询时再创建数组的开销。故算法总体时间复杂度为O（m+n）。
</p>
<br>进行重新配置编译下载，并进行测试，结果如下：
<br>![图片](https://github.com/Indifference061/Similarity-Join/assets/87850383/32bc5884-1b3c-4b13-a91b-61c36a57d9a3)
<br>![图片](https://github.com/Indifference061/Similarity-Join/assets/87850383/3c620e0d-c13c-47a2-92ff-5020f905ddb7)
<p>输入命令生成txt文件：</p>

```
$ HOME/pgsql/bin/psql similarity -c "SELECT ra.address,ap. address,ra. name,ap. phone FROM restaurantaddress ra, addressphone ap WHERE (levenshtein_distance(ra, address, ap. address) < 4) AND (ap. address LIKE '%Berkeley%’ OR ap. address LIKE '%Oakland%')ORDER BY 1，2，3，4" > levenshtein.txt
```
<br>![图片](https://github.com/Indifference061/Similarity-Join/assets/87850383/d5ab4d7b-4ec1-4f3b-9821-d273632db0fa)

### jaccard_index:

使用哈希表，建立一个二维数组bucket，对两个字符进行映射，并逐个扫描s1和s2，
- 初始化开头和结尾，加上‘$’并将其加入bucket
- 在扫描s1时，将字符对应的ascii码数值作为坐标，对于二维数组，若该数组该位置为1，则说明之前出现过，不做操作，若该数组在该位置为0，说明是之前未出现的二元字符，故将该位置置1，并令cntunion++。
- 在扫描s2时，同样判断bucket[s2[i]-' '][s2[i+1]-' ']，若为1，说明s1中有该二元字符，将其置2（防止后续重复计算cntinter），并让cntinter++，若为0，则说明s1中没有该二元字符，将其置为3，（防止后续重复计算cntunion），并让cntunion++，最后计算结果

```
Datum 
jaccard_index(PG_FUNCTION_ARGS)
{
    int i,j;
    text* str_01 = PG_GETARG_DATUM(0);
    text* txt_02 = PG_GETARG_DATUM(1);
    float4 result = 0.0;
    int cntunion=0,cntinter=0;
    char *s1 = text_to_cstring(str_01);
    char *s2=text_to_cstring(txt_02);
    static int bucket[130][130];
    memset(bucket,0,sizeof(bucket));
    int len1=strlen(s1),len2=strlen(s2);

    if(len1==0&&len2==0) 
        PG_RETURN_FLOAT4(1.0);
    else if(len1!=0&&len2!=0)
    {
        
        bucket['$'-' '][s1[0]-' ']=1;
        bucket[s1[len1-1]-' ']['$'-' ']=1;
        cntunion+=2;
        if(bucket['$'-' '][s2[0]-' ']==1)
        {
            bucket['$'-' '][s2[0]-' ']=2;
            cntinter++;
        }
        else cntunion++;
        if(bucket[s2[len2-1]-' ']['$'-' ']==1) 
        {
            bucket[s2[len2-1]-' ']['$'-' ']=2;
            cntinter++;
        }
        else cntunion++;

        for(i=0;i<len1-1;i++)
        {
            if(bucket[s1[i]-' '][s1[i+1]-' ']!=1)
            {
                bucket[s1[i]-' '][s1[i+1]-' ']=1;
                cntunion++;
            }
        }

        for(i=0;i<len2-1;i++)
        {
            // int a=s2[i]-' ',b=s2[i+1]-' ';
            if(bucket[s2[i]-' '][s2[i+1]-' ']==1)
            {
                bucket[s2[i]-' '][s2[i+1]-' ']=2;
                cntinter++;
            }
            else if(bucket[s2[i]-' '][s2[i+1]-' ']==0)
            {
                bucket[s2[i]-' '][s2[i+1]-' ']=3;//防止后续遍历发生自身union
                cntunion++;
            }
        }
    }
    result=(float4) cntinter/(float4) cntunion;
    PG_RETURN_FLOAT4(result);
}
```
<p>
  算法分析：时间复杂度为O（n+m）
</p>
<br>重新配置编译下载进行测试，结果如下：
<br>![图片](https://github.com/Indifference061/Similarity-Join/assets/87850383/4c164d63-89c3-464f-a10d-17dd491ac730)
<br>生成txt文件
<br>![图片](https://github.com/Indifference061/Similarity-Join/assets/87850383/dbd91172-0399-403a-a9bf-01cbd2afcc3a)
<br>![图片](https://github.com/Indifference061/Similarity-Join/assets/87850383/4ff05f73-a999-43f2-a0b6-3bead5e179fa)

---

## 实验总结
<p>
  本次实验在源码阅读、环境配置和优化算法上耗费很多时间。由于源码框架很大，但是实际添加修改函数只需要对sql执行有所理解，并通过网上对框架的解读进一步了解；环境配置方面，开始添加函数后，仍旧无法调用，解决方法是删库跑路（bushi）重新配置编译下载初始化；算法优化，在第二个函数的构思上，最开始想到的是O（m*n）的暴力匹配方法，但后来想到二维数组哈希可以将复杂度降到线性，故简化不少，牺牲空间优化时间并使算法简洁易懂。总体而言通过本次实验让我对PostgreSQL的框架运行有了更深入的认识。
</p>
