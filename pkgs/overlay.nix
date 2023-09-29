final: prev: {
  nvidiaPackages = final.lib.makeScope final.newScope (self: {
    driver = self.callPackage ./nvidia-driver {};
  });
}
