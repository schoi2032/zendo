import {execFileSync} from 'node:child_process';
import {mkdirSync,copyFileSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
if(process.platform!=='darwin')throw new Error('The Mac build needs macOS and Xcode Command Line Tools.');
const root=resolve(import.meta.dirname,'..');
const output=resolve(root,'desktop/build');
const bundle=resolve(output,'Zendo.app');
mkdirSync(resolve(bundle,'Contents/MacOS'),{recursive:true});
mkdirSync(resolve(bundle,'Contents/Resources'),{recursive:true});
mkdirSync(resolve(root,'public/downloads'),{recursive:true});
const run=(command,args)=>execFileSync(command,args,{cwd:root,stdio:'inherit'});
const sdk=execFileSync('xcrun',['--show-sdk-path'],{encoding:'utf8'}).trim();
for(const arch of ['arm64','x86_64']){
 run('xcrun',['swiftc','-swift-version','5','-O','-sdk',sdk,'-target',`${arch}-apple-macos14.0`,'-module-cache-path',resolve(output,'module-cache'),resolve(root,'desktop/Zendo.swift'),'-o',resolve(output,`Zendo-${arch}`)]);
}
run('lipo',['-create',resolve(output,'Zendo-arm64'),resolve(output,'Zendo-x86_64'),'-output',resolve(bundle,'Contents/MacOS/Zendo')]);
copyFileSync(resolve(root,'desktop/Info.plist'),resolve(bundle,'Contents/Info.plist'));
run('plutil',['-lint',resolve(bundle,'Contents/Info.plist')]);
const identity=process.env.ZENDO_SIGNING_IDENTITY;
if(identity){
 run('codesign',['--force','--options','runtime','--timestamp','--sign',identity,bundle]);
}else{
 run('codesign',['--force','--sign','-',bundle]);
 console.log('Development build: ad-hoc signed; Developer ID and notarization are still required for public distribution.');
}
const zip=resolve(root,'public/downloads/Zendo-Mac.zip');
run('ditto',['-c','-k','--sequesterRsrc','--keepParent',bundle,zip]);
if(identity&&process.env.ZENDO_NOTARY_PROFILE){
 run('xcrun',['notarytool','submit',zip,'--keychain-profile',process.env.ZENDO_NOTARY_PROFILE,'--wait']);
 run('xcrun',['stapler','staple',bundle]);
 run('ditto',['-c','-k','--sequesterRsrc','--keepParent',bundle,zip]);
 run('spctl',['--assess','--type','execute','--verbose=2',bundle]);
}
run('codesign',['--verify','--deep','--strict',bundle]);
run('lipo',['-info',resolve(bundle,'Contents/MacOS/Zendo')]);
if(!existsSync(zip))throw new Error('Mac download is missing.');
console.log(`Mac app: ${bundle}\nDownload: ${zip}`);
