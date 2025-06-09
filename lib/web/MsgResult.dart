

class MsgResult<T> {
  bool get isOk => this is MsgResultOk;
  bool get isError => this is MsgResultError;
  bool get isTimeoutError => this is MsgResultTimeoutError;

  T get ok => (this as MsgResultOk).data;
  String get errorMessage => (this as MsgResultError).message;
  MsgResultError<U> error<U>() {
    return (this as MsgResultError).cast<U>();
  }
}

class MsgResultOk<T> extends MsgResult<T> {
  final T data;

  MsgResultOk(this.data);
}

class MsgResultError<T> extends MsgResult<T> {
  final String message;

  MsgResultError(this.message);

  MsgResultError<U> cast<U>() {
    return MsgResultError<U>(message);
  }
}
class MsgResultTimeoutError<T> extends MsgResultError<T> {
  MsgResultTimeoutError(super.message);

  @override
  MsgResultError<U> cast<U>() {
    return MsgResultTimeoutError<U>(message);
  }
}
