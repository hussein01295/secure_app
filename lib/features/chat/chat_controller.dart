// ***************************************************************************
//  CHAT — REFACTO MODULAIRE EN MIXINS PAR SECTIONS  (VERSION CORRIGÉE)
//  ---------------------------------------------------------------------------
//  ✅ Mixins génériques (<T extends StatefulWidget>) pour éviter les conflits
//  ✅ Méthodes d'init publiques pour éviter collisions de noms privés
//  ✅ Délégations ChatService via Future.sync pour éviter use_of_void_result
// ***************************************************************************

import 'dart:async'; 
import 'dart:io';
 
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:silencia/core/service/auth_service.dart'; 
import 'package:silencia/core/service/ephemeral_service.dart';
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/utils/lang_map_generator.dart'; 
import 'package:silencia/core/services/media_encryption_service.dart';

import 'widgets/media/media_picker_widget.dart';
import 'chat_service.dart'; 
import 'controller/chat_vars.dart';

// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
