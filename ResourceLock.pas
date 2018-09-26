unit ResourceLock;

interface

uses Windows;

Type
    TezResourceLock = class
    protected 
      rlCritSect : TRTLCriticalSection;
    protected
    public
      constructor Create;
      destructor Destroy; override;

      procedure Lock;
      procedure Unlock;
  end;

implementation

constructor TezResourceLock.Create;
begin
  inherited Create;

  InitializeCriticalSection(rlCritSect);
end;

{--------}
destructor TezResourceLock.Destroy;
begin
  DeleteCriticalSection(rlCritSect);
  inherited Destroy;
end;
{--------}
procedure TezResourceLock.Lock;
begin
  EnterCriticalSection(rlCritSect);
end;
{--------}
procedure TezResourceLock.Unlock;
begin
  LeaveCriticalSection(rlCritSect);
end;

end.
