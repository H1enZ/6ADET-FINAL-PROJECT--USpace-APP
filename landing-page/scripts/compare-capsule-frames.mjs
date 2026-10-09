// Execute the original Dart _openingAt/_sealingAt functions in a standalone
// harness, then compare every field against the JS port at 101 timeline points.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { openingAt, sealingAt, OPEN_MS, SEAL_MS } from '../src/capsule-frames.js';
const root=new URL('../',import.meta.url);
const source=await readFile(new URL('../lib/widgets/capsule/candle_ceremony.dart',root),'utf8');
const functions=source.slice(source.indexOf('double _span('),source.indexOf('/// The sealing ceremony.'));
if(!source.includes(`milliseconds: ${OPEN_MS}`)||!source.includes(`milliseconds: ${SEAL_MS}`))throw Error('Flutter duration mismatch');
const keys=Object.keys(openingAt(0));
const stub=`import 'dart:convert';
class Curve { const Curve(this.a,this.b,this.c,this.d); final double a,b,c,d;
 double transform(double x) { if(x==0||x==1)return x; double low=0,high=1; double f(double t,double p,double q)=>3*(1-t)*(1-t)*t*p+3*(1-t)*t*t*q+t*t*t;
 while(true){final t=(low+high)/2;final estimate=f(t,a,c);if((x-estimate).abs()<0.001)return f(t,b,d);if(estimate<x){low=t;}else{high=t;}}
 }}
class Curves { static const easeInOutCubic=Curve(.645,.045,.355,1); static const easeOutCubic=Curve(.215,.61,.355,1); static const easeInCubic=Curve(.55,.055,.675,.19); static const easeInQuad=Curve(.55,.085,.68,.53); }
`;
const main=`void main(){ final results=[];for(var i=0;i<=100;i++){ final t=i/100;for(final f in [_openingAt(t),_sealingAt(t)])results.add({${keys.map(key=>`'${key}':f.${key}`).join(',')}});}print(jsonEncode(results));}`;
await mkdir(new URL('qa/',root),{recursive:true});
const harness=new URL('qa/flutter-frame-reference.dart',root);
await writeFile(harness,stub+functions+main);
const dart=process.argv[2]||'dart';
const frames=JSON.parse(execFileSync(dart,[fileURLToPath(harness)],{encoding:'utf8'}));
let maxError=0;
for(let i=0;i<=100;i++)for(const [j,fn] of [openingAt,sealingAt].entries())for(const key of keys){const actual=[fn(i/100)[key]].flat(),expected=[frames[i*2+j][key]].flat();actual.forEach((v,k)=>{maxError=Math.max(maxError,Math.abs(v-expected[k]));});}
if(maxError>1e-9)throw Error(`Frame mismatch: ${maxError}`);
const result={frames:202,fields:keys.length,maxError,tolerance:1e-9,openingMs:OPEN_MS,sealingMs:SEAL_MS};
await writeFile(new URL('qa/capsule-frame-comparison.json',root),JSON.stringify(result,null,2));
console.log(JSON.stringify(result));
