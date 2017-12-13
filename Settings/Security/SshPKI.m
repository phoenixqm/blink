#include <libssh/libssh.h>
#import "SshPKI.h"


@implementation SshPKI {
  ssh_key _key;
  enum ssh_keytypes_e _type;
}

- (SshPKI *)initFromPrivateKey:(NSString *)privateKey passphrase:(NSString *)passphrase
{
  self = [super init];
  const char *ckey = [privateKey UTF8String];
  const char *pp = (passphrase) ? [passphrase UTF8String] : NULL;

  if (self) {
    // TODO: Note that the auth_fn as NULL might not be the best for us, as then we have to figure out whether or
    // not the key is encrypted outside here, while we could show an alert in this case
    if (ssh_pki_import_privkey_base64(ckey, pp, NULL, NULL, &_key)) {
      return nil;
    }

    _type = ssh_key_type(_key);
    
    return self;
  }
  return nil;
}

- (SshPKI *)initWithType:(enum ssh_keytypes_e)type length:(int)bits
{
  self = [super init];

  if (self) {
    if (ssh_pki_generate(type, bits, &_key)) {
      return nil;
    }

    _type = type;

    return self;
  }
  return nil;
}

- (NSString *)privateKey
{
  return [self privateKeyWithPassphrase:nil];
}

- (NSString *)privateKeyWithPassphrase:(NSString *)passphrase
{
  const char *pp = (passphrase.length) ? [passphrase UTF8String] : NULL;

  // Open file, read to memory, remove file and return the string
  NSString *root = (NSString *)[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
  NSString *filePath = [root stringByAppendingPathComponent:@"tempPrivKey"];

  if (ssh_pki_export_privkey_file(_key, pp, NULL, NULL, [filePath UTF8String])) {
    // TODO: What happens if the file is already there? Handle error cases
    return nil;
  }
  
  NSString *str = [self readOnceKeyFromFile:filePath];
  return str;
}

- (NSString *)publicKeyWithComment:(NSString *)comment
{
  char *ckey;
  ssh_key pub_key;
  
  ssh_pki_export_privkey_to_pubkey(_key, &pub_key);

  if (ssh_pki_export_pubkey_base64(pub_key, &ckey)) {
    return nil;
  }
  
  NSString *str = [NSString stringWithFormat:@"%s %s %@\n", ssh_key_type_to_char(_type), ckey, comment];

  return str;
}

- (NSString *)readOnceKeyFromFile:(NSString *)filePath
{
  // TODO: NSString or NSData
  // Read and remove file
  NSString *content = [NSString stringWithContentsOfFile:filePath
						encoding:NSUTF8StringEncoding
						   error:NULL];
  [[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];

  return content;
}

@end
