struct connector {
  void *ud;
  void (*callback)(int fd, void *ud);
};