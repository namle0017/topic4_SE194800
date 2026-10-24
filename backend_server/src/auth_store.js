class InMemoryAuthStore {
  constructor() {
    this.usersByEmail = new Map();
    this.verificationsById = new Map();
  }

  findUserByEmail(email) {
    return this.usersByEmail.get(email) ?? null;
  }

  saveUser(user) {
    this.usersByEmail.set(user.email, user);
  }

  deleteUser(email) {
    this.usersByEmail.delete(email);
  }

  findVerificationById(id) {
    return this.verificationsById.get(id) ?? null;
  }

  saveVerification(verification) {
    this.verificationsById.set(verification.id, verification);
  }

  deleteVerification(id) {
    this.verificationsById.delete(id);
  }
}

module.exports = { InMemoryAuthStore };
