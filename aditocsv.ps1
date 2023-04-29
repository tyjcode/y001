#
# JTDX の wsjtx_log.adi をコピーして ターボハムログ インポート用の csv ファイルを作成
#


#
# ファイル
#
# パス取得
$path = Split-Path -Parent $MyInvocation.MyCommand.Path

# HAMLOGの全ログ(予めファイルへ出力しておく)
$logFileName = $path + "\LogList.csv"

# JTDXのADIF ファイル(コピーして利用される)
$wsjxpath = $env:USERPROFILE + "\AppData\Local\JTDX\wsjtx_log.adi"

#作成されるファイル
$inFileName = $path + "\wsjtx_log.adi"
$jsonFileName = $path + "\wsjtx_log.adi.json"
$outFileName = $path + "\wsjtx_log.adi.csv"

# HAMLOGにインポートするファイル
$outFileName1 = $path + "\wsjtx_log.adi-1.csv"




#
# アイテムの変換
#
function todate($strdate)
{
    # xxyymmdd
    return( $strdate.Substring(2,2) + "/" + $strdate.Substring(4,2) + "/" + $strdate.Substring(6,2))
  
}
function totime($strtime)
{
  return( $strtime.Substring(0,2) + ":" + $strtime.Substring(2,2) + "U" )
  
}
function tofeq($strfeq)
{
    $s = $strfeq.split(".")
  return($s[0] + "." + $s[1].Substring(0,3))
  
}
function tomodeft($strmode)
{
    if ($strmode -eq "MFSK")
    {
        $rc = "FT4"
    }
    else
    {
        $rc = $strmode
    }

  return($rc.trim())
  
}
function toprefecture($strpark)
{
    if ($strpark -eq $null)
    {
        return($strpark)
    }
    else
    {
        return( $strpark.Split("_")[2] )
     }
  
}
function topark($strpark)
{
    if ($strpark -eq $null)
    {
        return($strpark)
    }
    else
    {
        $p = $strpark.Split("_")
        return($p[0] + " " + $p[1])
     }
  
}

#
# adi から csv ファイルへ変換
#
function tocsv()
{
    #
    # JSON形式に変換
    #
    $infile = New-Object System.IO.StreamReader($inFileName, [System.Text.Encoding]::GetEncoding("sjis"))
    $line = $infile.ReadLine()# 1行目はスキップ

    $strjson = "["
    while (($line = $infile.ReadLine()) -ne $null)
    {
        $splitline = $line.Split("<")

        $strjson += "{"
        foreach($item in $splitline)
        {
            if ($item[0] -eq $null) { continue } # 項目名が無い時がある
       
            $splititem = $item.Split(">")
            $itemname = $splititem[0].Split(":")[0].Trim()

            if ($splititem[1] -eq $null)
            {
                # 値が無い時は "" とする
                $itemvalue = ""
            }
            else
            {
                # 値の文字列を整形
                $itemvalue = $splititem[1].Trim()
                $itemvalue = $itemvalue -replace "\t","_"
            }
            $strjson += ("""" + $itemname+ """: """ + $itemvalue + """,")                    
        }
        $strjson = $strjson.Substring(0, $strjson.Length - 1);
        $strjson += "},"
    }
    $strjson = $strjson.Substring(0, $strjson.Length - 1);
    $strjson += "]"
    
    $infile.Close()

    # JSON 形式化
    $psobj　= ConvertFrom-Json $strjson
    Out-File $jsonFileName -Encoding utf8 -InputObject $strjson


    #
    # CSV形式に変換
    #
    $outfile =  New-Object System.IO.StreamWriter($outFileName, $ture, [System.Text.Encoding]::GetEncoding("sjis"))
    foreach($item in $psobj)
    {
        $d = todate($item.qso_date) 
        $t = totime($item.time_on)
        $f = tofeq($item.freq)
        $m = tomodeft($item.mode)
        $pr = toprefecture($item.comment)
        $pa = topark($item.comment)

        $csvline = """" + $item.call + """,""" 
        $csvline = $csvline + $d + """,""" + $t + """,""" 
        $csvline = $csvline + $item.rst_sent + """,""" + $item.rst_rcvd + """,""" 
        $csvline = $csvline + $f + """,""" + $m + """,""" 
        $csvline = $csvline + """,""" + $item.gridsquare + """,""N"",""" + $item.name + ""","""
        $csvline = $csvline + $pr + """,""" 
        $csvline = $csvline + $pa + """,""" 
        $csvline = $csvline + """," + """0"""
         
        $outfile.WriteLine( $csvline )
        Write-Host($csvline)
    }
    $outfile.Close()
}

function addname()
{
    $inheader = @("call","date","time","rstsent","rstrcvd","freq","mode","code","grid","qsl","name","qth","commnet1","commnet2","dc12")
    $incsv = Import-CSV -Encoding Default -Header $inheader -Path $outFileName
    $logcsv = Import-CSV -Encoding Default -Header $inheader -Path $logFileName

    foreach($i in $incsv)
    {
        $icall = $i.call.Split("/")
        foreach($l in $logcsv)
        {
            $lcall = $l.call.Split("/")
            if($icall[0] -eq $lcall[0])
            {
                $i.name = $l.name
                if($i.qth  -eq "") { $i.qth = $l.qth }
                if($l.qsl.Substring(0,1) -eq "E") { $i.qsl = "E" }
                break
            }
        }
    }

    $incsv | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Set-Content -Encoding Default -Path $outFileName1
}
#
# 実行
#

#変換元のファイルをコピー
copy $wsjxpath $inFileName

#csvファイルへ変換
tocsv

#OP名を追加
addname

#作成したファイルを開く
notepad $outFileName1

