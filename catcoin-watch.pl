#!/usr/bin/perl -w

no warnings 'uninitialized';
use JSON;
use LWP;
use Time::Duration;
use Date::Parse;

$now = time();

# Best if run in under watch 
# watch -pn 60 ./catcoin-watch.pl

$api = 'apikey';
$uid = 'uid';
$mypool = 'teamcatcoin.com';
$p2paddr = 'CATaddr';

$ua = new LWP::UserAgent;
$ua->agent('Statchecker/0.01 ');
@otherpools = qw(cat.coinium.org catpool.in cat.hashfaster.com cat.mintpool.co cat.cryptovalley.com);
@p2pools = qw(p2pool.name:9333 solidpool.org:9333 p2pool.org:9999 cat.e-pool.net:9993 minbar.hozed.org:9927);

# Wallet Info
$catmine = readpipe('catcoind getmininginfo'); 
$catmined = decode_json $catmine;
$catinfo = readpipe('catcoind getinfo');
$catinfod = decode_json $catinfo;
$nethash = $catmined->{'networkhashps'} / 1000;
$catpeers = readpipe('catcoind getpeerinfo');
$catpeers = decode_json $catpeers;

# TeamCatcoin data
$catpoolbreq = new HTTP::Request('GET', "http://$mypool/index.php?page=api&action=getdashboarddata&api_key=$api&id=$uid");
$catpoolbrep = $ua->request($catpoolbreq);
if ( $catpoolbrep->code == 503) {
    sleep(3);
    $catpoolbrep = $ua->request($catpoolbreq);
}
elsif ( $catpoolbrep->code == 200 ) {
    $catpoolbinfo = $catpoolbrep->content;
    $catpoolbinfo = decode_json $catpoolbinfo;
    $catpoolbinfo = $catpoolbinfo->{'getdashboarddata'}{'data'};
} 
else {
    $catpoolbinfo = 'N/A';
};

sleep(1);
$catpoolsreq = new HTTP::Request('GET', "http://$mypool/index.php?page=api&action=getpoolstatus&api_key=$api&id=$uid");
$catpoolsrep = $ua->request($catpoolsreq);
if ( $catpoolsrep->code == 200 ) {
    $catpoolsinfo = $catpoolsrep->content;
    $catpoolsinfo = decode_json $catpoolsinfo;
    $catpoolsinfo = $catpoolsinfo->{'getpoolstatus'}{'data'};
}
else {
    $catpoolsinfo = 'N/A';
};

sleep(1);

$catpoolfreq = new HTTP::Request('GET', "http://$mypool/index.php?page=api&action=getblocksfound&api_key=$api&id=$uid");
$catpoolfrep = $ua->request($catpoolfreq);
if ( $catpoolfrep->code == 200 ) {
    $catpoolfinfo = $catpoolfrep->content;
    $catpoolfinfo = decode_json $catpoolfinfo;
    $catpoolfinfo = $catpoolfinfo->{'getblocksfound'}{'data'};
}
else {
    $catpoolfinfo = 'N/A';
};


$cplastblock = &timeformat($catpoolsinfo->{'timesincelast'});
#$cproundest = sprintf("%.3f", $catpoolbinfo->{'personal'}{'shares'}{'valid'} / $catpoolbinfo->{'pool'}{'shares'}{'valid'} * 48);
$cppcent = sprintf("%.3f",$catpoolsinfo->{'hashrate'} / $nethash * 100);

# Other Pools data
@pooldata = ();
$othercnt = @otherpools;
for($i=0; $i<$othercnt; $i++) {
    $poolreq = new HTTP::Request('GET', 'http://'.$otherpools[$i].'/index.php?page=api&action=public');
    $poolrep = $ua->request($poolreq);
    if ( $poolrep->code == 200 ) {
        $poolinfo = $poolrep->content;
        $poolinfo = decode_json $poolinfo;
        $pooldata[$i] = $poolinfo;
    };
};

# CoinEx data
$coinexreq = new HTTP::Request('GET','https://coinex.pw/api/v2/currencies?name=CAT');
$coinexrep = $ua->request($coinexreq);
if ( $coinexrep->code == 200 ) {
    $coinexinfo = $coinexrep->content;
    $coinexinfo = decode_json $coinexinfo;
    $coinexinfo = $coinexinfo->{'currencies'};
    $coinexlastblk = $coinexinfo->[0]{'last_block_at'};
    #$coinexlastblk =~ s/T/ /;
    #$coinexlastblk =~ s/\.\d+Z/ UTC/;
    $coinexdte = str2time($coinexlastblk);
    $coinexdte -= $now;
    $coinexago = &timeformat($coinexdte);
};

# P2Pools data
@p2pooldata = ();
@p2poolhash = ();
$p2poolcnt = @p2pools;
# Local data
for($i=0; $i<$p2poolcnt; $i++) {
    $total = 0;
    $p2poolreq = new HTTP::Request('GET','http://'.$p2pools[$i].'/local_stats');
    $p2poolrep = $ua->request($p2poolreq);
    if ($p2poolrep->code == 200 ) {
        $p2poolinfo = $p2poolrep->content;
        $p2poolinfo = decode_json $p2poolinfo;
        $miners = $p2poolinfo->{'miner_hash_rates'};
        foreach $miner (values %$miners) {
            $total += $miner;
        };
        $p2poolhash[$i] = $total;
        $p2pooldata[$i] = $p2poolinfo;
    }
    else {
        $p2poolhash[$i] = "0";
        $p2pooldata[$i] = "0";
    };
};
# Global data
$p2poolgreq = new HTTP::Request('GET','http://'.$p2pools[0].'/global_stats');
$p2poolgrep = $ua->request($p2poolgreq);
if ( $p2poolgrep->code == 200 ) {
    $p2poolginfo = $p2poolgrep->content;
    $p2poolginfo = decode_json $p2poolginfo;
};

$p2poolbreq = new HTTP::Request('GET','http://'.$p2pools[0].'/recent_blocks');
$p2poolbrep = $ua->request($p2poolbreq);
if ( $p2poolbrep->code == 200 ) {
    $p2poolbinfo = $p2poolbrep->content;
    $p2poolbinfo = decode_json $p2poolbinfo;
    $p2poolbtime = $p2poolbinfo->[0]{'ts'};
    $p2poolbhash = $p2poolbinfo->[0]{'hash'};
    $p2pblockinfo = readpipe("catcoind getblock $p2poolbhash");
    if ( $p2pblockinfo =~ /Block not/ && defined $p2poolbhash ) {
        $p2pblockinfo = decode_json $p2pblockinfo;
        $p2pblock = $p2pblockinfo->{'height'};
    }
    else {
        $p2pblock = 'Bad blockhash';
    };
};


if ( !defined $p2poolbtime ) {
    $p2pblocktime = "N/A";
}
else {
    $p2pblocktime = &timeformat($now - $p2poolbtime);
};

if ( !defined $p2poolbhash ) {
    $p2pblock = "N/A";
};
if ( $p2pblock eq '' ) {
    $p2pblock = 'N/A';
};

$p2ppayoutreq = new HTTP::Request('GET','http://'.$p2pools[0].'/current_payouts');
$p2ppayoutrep = $ua->request($p2ppayoutreq);
if ( $p2ppayoutrep->code == 200 ) {
    $p2ppayoutinfo = $p2ppayoutrep->content;
    $p2ppayoutinfo = decode_json $p2ppayoutinfo;
    $p2ppayout = $p2ppayoutinfo->{$p2paddr};
}
else {
    $p2ppayout = "Not Avail.";
};

# Get Block age
$current = readpipe('catcoind getbestblockhash');
$currentbinfo = readpipe("catcoind getblock $current");
$currentbinfo = decode_json $currentbinfo;
$currentbage = $currentbinfo->{'time'};
$currentbage -= $now;
$blockage = &timeformat($currentbage);

# Wallet Peers
$t = 0;
$catinbound = 0;
$catoutbound = 0;
for ($t=0; $t<$catinfod->{'connections'}; $t++) {
    if ( grep(/9933/, $catpeers->[$t]{'addr'}) == 1 ) {
        $catoutbound++;
    }
    else {
        $catinbound++;
    };
};
$peertotal = $t;

# Setup varibles for printing
@mypoolinfo = ('Last Block:', 'Round Time:', 'Round est.:', 'Balance:', 'My Hashrate:', 'Pool Hashrate:', 'Hash %:', 'Workers:');
@otherpoolinfo = ('Pool Name:','Last Block', 'Hashrate:', 'Hash %:', 'Workers:');
@p2pooltype = ('Pool Name:', 'Peers:', 'Local Hash:', 'P2P Hash %:', 'Net Hash %:');
$format = "%-14s";
$format2 = "%-15s";
$format3 = "%-18s";
$format4 = "%-7s";
$ototal = 0;
@blockinfo =();

for ($i=0; $i<8; $i++) {
    $blockinfo[$i] = sprintf("$format4 $format4  $format4",$catpoolfinfo->[$i]{'height'},(35 - $catpoolfinfo->[$i]{'confirmations'}),$catpoolfinfo->[$i]{'finder'});
};
for ($i=0; $i<$othercnt; $i++) {
    $name = ${pooldata[$i]}->{'pool_name'};
    $name =~ s/CAT Pool @ //;
    $name =~ s/^CatCoin Pool$/MintPool/;
    $name =~ s/CatCoin Pool//;
    $name =~ s/Cat Coin//;
    $name =~ s/The Catcoin//;
    $name =~ s/ - //;
    $name =~ s/\.com//;
    $pcent = sprintf("%.3f",${pooldata[$i]}->{'hashrate'} / $nethash * 100);
    $ototal += $pcent;
    $othername .= sprintf($format,$name);
    $otherhash .= sprintf($format,(${pooldata[$i]}->{'hashrate'} / 1000)." MH/s");
    $otherpcent .= sprintf($format,"$pcent%");
    $otherworker .= sprintf($format,${pooldata[$i]}->{'workers'});
    $otherblock .= sprintf($format,${pooldata[$i]}->{'last_block'});
};

$p2ptotal = 0;
for ($i=0; $i<$p2poolcnt; $i++) {
    $name = $p2pools[$i];
    $name =~ s/:.*//;
    $p2pname .= sprintf($format2,$name);
    $p2ppeers .= sprintf($format2,"In: ".${p2pooldata[$i]}->{'peers'}{'incoming'}." Out: ".${p2pooldata[$i]}->{'peers'}{'incoming'});
    $p2plhash .= sprintf($format2,(sprintf("%.3f",$p2poolhash[$i] / 1000000)." MH/s"));
    $pcent = sprintf("%.3f",(${p2poolhash[$i]} / $catmined->{'networkhashps'} * 100));
    $p2ptotal += $pcent;
    $p2pgpcent .= sprintf($format2,"$pcent%");
    $p2pnpcent .= sprintf($format2,(sprintf("%.3f",($p2poolhash[$i] / $p2poolginfo->{'pool_hash_rate'} * 100))).'%');
};

$coinexpcent = sprintf("%.3f",($coinexinfo->[0]{'hashrate'} / ($catmined->{'networkhashps'} / 1000)) * 100);
if ( defined $coinexdte) {
    $coinexdur = &timeformat($coinexdte);
}
else {
    $coinexdur = 'N/A';
};

# Print info.
print "Pools that I'm in\n";
printf "$format $format3 $format4 $format4 $format4\n","Statistic","TeamCatcoin.com","Block","Confirms","Finder";
printf "$format $format3 %s\n",$mypoolinfo[0],$catpoolsinfo->{'lastblock'},$blockinfo[0];
printf "$format $format3 %s\n",$mypoolinfo[1],$cplastblock,$blockinfo[1];
printf "$format $format3 %s\n",$mypoolinfo[2],sprintf("%.3f",$catpoolbinfo->{'personal'}{'estimates'}{'payout'}),$blockinfo[2];
printf "$format $format3 %s\n",$mypoolinfo[3],'C: '.sprintf("%.3f",$catpoolbinfo->{'personal'}{'balance'}{'confirmed'}).' U: '.sprintf("%.3f",$catpoolbinfo->{'personal'}{'balance'}{'unconfirmed'}),,$blockinfo[3];
printf "$format $format3 %s\n",$mypoolinfo[4],$catpoolbinfo->{'personal'}{'hashrate'}." KH/s",$blockinfo[4];
printf "$format $format3 %s\n",$mypoolinfo[5],sprintf("%.3f", $catpoolsinfo->{'hashrate'} / 1000)." MH/s",$blockinfo[5];
printf "$format $format3 %s\n",$mypoolinfo[6],"$cppcent%",$blockinfo[6];
printf "$format $format3 %s\n",$mypoolinfo[7],$catpoolsinfo->{'workers'},$blockinfo[7];

print "\nOther Pool info\n";
printf "%-12s %s $format\n",$otherpoolinfo[0],$othername,"CoinEx";
printf "%-12s %s $format\n",$otherpoolinfo[1],$otherblock,"$coinexago";
printf "%-12s %s $format\n",$otherpoolinfo[2],$otherhash,($coinexinfo->[0]{'hashrate'} / 1000)." MH/s";
printf "%-12s %s $format\n",$otherpoolinfo[3],$otherpcent,$coinexpcent.'%';
printf "%-12s %s $format\n",$otherpoolinfo[4],$otherworker,"N/A";

print "\nP2Pool info\n";
printf "%-12s %s\n",$p2pooltype[0],$p2pname;
printf "%-12s %s\n",$p2pooltype[1],$p2ppeers;
printf "%-12s %s\n",$p2pooltype[2],$p2plhash;
printf "%-12s %s\n",$p2pooltype[3],$p2pnpcent;
printf "%-12s %s\n",$p2pooltype[4],$p2pgpcent;
print "\nP2Pool Global info\n";
printf "%-12s %s\n","Global Hash:",sprintf("%.3f", ($p2poolginfo->{'pool_hash_rate'} / 1000000))." MH/s (".sprintf("%.3f",($p2poolginfo->{'pool_hash_rate'} / $catmined->{'networkhashps'} * 100)).'%)';
printf "%-12s %s\n","Last Block:",$p2pblock;
printf "%-12s %s\n","Round Time:",$p2pblocktime;
printf "%-12s %s\n","Payout:",$p2ppayout;

print "\nMy Wallet info\n";
print "Balance:       ".$catinfod->{'balance'}." CAT\n\n";

print "Network info\n";
print "Connections:   $peertotal (IN: $catinbound, OUT: $catoutbound)\n";
print "Current Block: ".$catmined->{'blocks'}.", Next: ".($catmined->{'blocks'} + 1)."\n";
print "Block Age:     $blockage\n";
print "Block Size:    ".$catmined->{'currentblocksize'}."\n";
print "Block Tx:      ".$catmined->{'currentblocktx'}."\n";
print 'Difficulty:    '.$catmined->{'difficulty'}."\n";
print 'Hashrate:      '.sprintf("%.3f", $catmined->{'networkhashps'} / 1000000)." MH/s\n";
print 'Pcent watched: '.($ototal + $p2ptotal + $cppcent + $coinexpcent)."%\n";
#print Dumper($catmined);



sub timeformat($) {
    my $rawtime = shift;
    my $time = duration($rawtime,4);
    $time =~ s/ (day,|days,|day and|days and) /D-/;
    $time =~ s/ (hours|hour)/h/;
    $time =~ s/ (minutes|minute)/m/;
    $time =~ s/ (seconds|second)/s/;
    $time =~ s/(, and| and) /:/g;
    $time =~ s/, /:/g;
    return $time;
}
