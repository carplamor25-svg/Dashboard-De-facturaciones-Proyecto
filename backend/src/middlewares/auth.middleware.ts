import { FastifyRequest, FastifyReply } from 'fastify';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

export interface UserSessionPayload {
  userId: string;
  orgId: string;
  email: string;
  roles: string[];
}

declare module 'fastify' {
  interface FastifyRequest {
    user?: UserSessionPayload;
  }
}

/**
 * Middleware para validar cookies HttpOnly firmadas que contienen el JWT de sesión.
 */
export async function authenticateSession(request: FastifyRequest, reply: FastifyReply) {
  try {
    const token = request.cookies?.session_token || request.headers.authorization?.replace('Bearer ', '');

    if (!token) {
      return reply.status(401).send({
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Sesión no iniciada o token ausente.'
      });
    }

    const decoded = jwt.verify(token, env.JWT_SECRET) as UserSessionPayload;
    request.user = decoded;
  } catch (err) {
    return reply.status(401).send({
      statusCode: 401,
      error: 'Unauthorized',
      message: 'Sesión inválida o expirada.'
    });
  }
}

/**
 * Middleware RBAC para restringir rutas a roles específicos (ej. admin o auditor).
 */
export function requireRole(allowedRoles: string[]) {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) {
      return reply.status(401).send({ message: 'No autenticado.' });
    }

    const hasPermission = request.user.roles.some(role => allowedRoles.includes(role));
    if (!hasPermission) {
      return reply.status(403).send({
        statusCode: 403,
        error: 'Forbidden',
        message: 'Acceso denegado: no dispones de los permisos suficientes para esta acción.'
      });
    }
  };
}

