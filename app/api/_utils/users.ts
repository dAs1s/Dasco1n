
import { prisma } from './prisma';
export async function findUserByUsernameInsensitive(username: string) {
  return prisma.user.findFirst({
    where: { username: { equals: username, mode: 'insensitive' } },
  });
}
